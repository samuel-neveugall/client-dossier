#!/usr/bin/env python3
# vibeflow:allow-large-file -- one file on purpose: a bare-skills copy runs it
# by path, so a second importable module would turn sys.path into a
# distribution concern (DIST-03). Every CALL-03 item is one cohesive pass over
# the same dossier. Tracked in 06-02-SUMMARY.md.
"""Compute the dossier status report for a client-dossier repository.

Mechanics tier only (spec principle: "skills carry the judgement, scripts
carry the mechanics"). Every date, git and header rule of CALL-03 is computed
here; what to say about it, and what to do next, lives in
skills/dossier-status/SKILL.md. The script is READ-ONLY: it opens no file for
writing, starts only `git log`, `git ls-files`, `git diff --cached
--name-only` and `git rev-parse` (each with --no-optional-locks so no index
refresh is written) and the linter, and reads no setting from the process surroundings.

Usage:
    status.py [--json] [--today YYYY-MM-DD] [--lint PATH] [PATH]

PATH is a path inside the dossier (default: the current directory); the
nearest dossier.yaml found by walking upward is the root. --today fixes the
date the report is computed for (tests; default: the local date). --lint
names the linter to run (tests; default: scripts/lint.py of this repository).
Text is printed by default; --json prints one ASCII-only JSON object.

Exit codes: 0 a report was printed (whatever it holds: status is
informational, not a gate), 2 the path does not exist, no dossier.yaml was
found upward, dossier.yaml is unreadable, or the arguments are invalid, 3
internal error.

Why the linter is found from __file__: the plugin-root variable is
substituted in skill text but is empty in the Bash tool (06-RESEARCH P1), so
the script locates scripts/lint.py from its own real location. Why lint runs
as a subprocess: importing it would write bytecode next to the plugin's
scripts/.

Python 3 standard library only, targeting Python >= 3.8.
"""

import argparse
import datetime
import json
import os
import re
import subprocess
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# PORTED FROM scripts/lint.py -- pinned by tests/test-status-script.sh
# (find_root byte-identical, these assignments AST-identical).
# ---------------------------------------------------------------------------

CONFIG_NAME = "dossier.yaml"

LIVING_DIR = "dossier"
LIVING_FILES = (
    "ACTORS.md",
    "HISTORY.md",
    "LEARNINGS.md",
    "TONE.md",
    "CHANNELS.md",
    "OPEN-QUESTIONS.md",
    "RELATIONSHIP.md",
)

OUTBOUND_DIR = "outbound"
EXEMPT_PATHS = frozenset((OUTBOUND_DIR + "/README.md",))
OS_METADATA_NAMES = frozenset((".DS_Store", "Thumbs.db", "desktop.ini"))
GITKEEP = ".gitkeep"
BINARY_EXTS = frozenset((
    ".pdf", ".docx",
    ".png", ".jpg", ".jpeg", ".gif", ".webp",
    ".odt", ".pptx", ".xlsx",
))

PROTOCOL_FIELDS = ("Status", "To", "Subject", "Deadline", "Written by", "Rules")
STATUS_HEADER_WINDOW = 10
DEFAULT_STALENESS_DAYS = 7

_LAST_UPDATED_RE = re.compile(r"^[ \t]*Last updated:[ \t]*(.*)$")
_DATE_PREFIX_RE = re.compile(r"([0-9]{4})-([0-9]{2})-([0-9]{2})(?![0-9])")
_FIELD_RE = re.compile(
    r"[^A-Za-z0-9]*?\b(" + "|".join(re.escape(field) for field in PROTOCOL_FIELDS)
    + r"):[ \t]*(.*?)[ \t]*(?:-->)?[ \t]*"
)

# ---------------------------------------------------------------------------
# CONSTANTS OF THIS SCRIPT
# ---------------------------------------------------------------------------

SOURCES_DIR = "sources"
README_NAME = "README.md"
MAX_READ_BYTES = 5000000
SOON_DAYS = 7
GIT_TIMEOUT = 10
LINT_TIMEOUT = 60

EXIT_OK = 0
EXIT_NO_DOSSIER = 2
EXIT_INTERNAL = 3

_COMMENT_OPEN = "<!--"
_COMMENT_CLOSE = "-->"
_FENCES = ("```", "~~~")
_BULLET_PREFIXES = ("- ", "* ")

_DATE_RE = re.compile(r"([0-9]{4})-([0-9]{2})-([0-9]{2})")
_TODAY_RE = re.compile(r"[0-9]{4}-[0-9]{2}-[0-9]{2}")
_ISO_DATE_RE = re.compile(r"(?<![0-9])([0-9]{4})-([0-9]{2})-([0-9]{2})(?![0-9])")
_TRAILING_SOURCE_RE = re.compile(r"\(([^()]+)\)\.?\s*$")
_DONE_RE = re.compile(r"\bdone[ \t]+([0-9]{4})-([0-9]{2})-([0-9]{2})(?![0-9])", re.IGNORECASE)
_STALENESS_RE = re.compile(r"^staleness_days[ \t]*:[ \t]*(.*)$", re.MULTILINE)
_GIT_STAMP_RE = re.compile(r"@[0-9]+")
_LINT_FINDING_RE = re.compile(r"(.*?):([0-9]+): (ERROR|WARNING) \[([A-Za-z0-9]+)\] (.*)")
_LINT_SUMMARY_RE = re.compile(r"([0-9]+) error\(s\), ([0-9]+) warning\(s\)")


# ---------------------------------------------------------------------------
# ROOT DISCOVERY
# ---------------------------------------------------------------------------


def find_root(start):
    """The nearest directory at or above `start` holding dossier.yaml.

    No stop condition (D-01, Q-4): a dossier legitimately lives inside a
    larger repository, so the walk does not stop at `.git`. Returns None
    when no dossier.yaml exists anywhere up to the filesystem root.
    """
    here = Path(os.path.realpath(start))
    if not here.is_dir():
        here = here.parent
    for candidate in (here,) + tuple(here.parents):
        if os.path.isfile(os.path.join(str(candidate), CONFIG_NAME)):
            return str(candidate)
    return None


# ---------------------------------------------------------------------------
# SMALL PORTED HELPERS
# ---------------------------------------------------------------------------


def read_text_safe(path):
    """The decoded UTF-8 text of `path`, or None -- never an exception.

    A symlinked file is skipped before it is opened, anything but a regular
    file (a FIFO would block) is skipped, a file over MAX_READ_BYTES is
    skipped, and a decode or OS error returns None. Opens read-only.
    """
    try:
        if os.path.islink(path):
            return None
        if not os.path.isfile(path) or os.path.getsize(path) > MAX_READ_BYTES:
            return None
        with open(path, "rb") as handle:
            data = handle.read(MAX_READ_BYTES + 1)
        if len(data) > MAX_READ_BYTES:
            return None
        return data.decode("utf-8-sig")
    except (OSError, ValueError):
        return None


def sanitise_path(rel):
    """Escape every control character in a printed line (T-06-09).

    A filename may legally contain a newline or an escape sequence; printed
    raw it forges report lines a model would believe. Escaped as \\xNN: C0
    controls, DEL, C1 controls and the surrogate-escaped bytes os.walk returns
    for a name that is not valid UTF-8. U+2028/U+2029 are escaped as \\uNNNN.
    """
    out = []
    for ch in rel:
        code = ord(ch)
        if code < 0x20 or 0x7F <= code <= 0x9F:
            out.append("\\x{:02x}".format(code))
        elif 0xDC80 <= code <= 0xDCFF:
            out.append("\\x{:02x}".format(code - 0xDC00))
        elif code in (0x2028, 0x2029):
            out.append("\\u{:04x}".format(code))
        else:
            out.append(ch)
    return "".join(out)


def _is_real_date(year, month, day):
    try:
        datetime.date(int(year), int(month), int(day))
    except ValueError:
        return False
    return True


def is_absolute_date(text):
    """True when TEXT is exactly YYYY-MM-DD and a real calendar date."""
    match = _DATE_RE.fullmatch(text)
    return match is not None and _is_real_date(*match.groups())


def _to_date(text):
    year, month, day = text.split("-")
    return datetime.date(int(year), int(month), int(day))


def visible_lines(text):
    """(line number, the line with HTML comments removed), outside fenced code.

    A depth counter survives across lines, so a bullet inside a multi-line
    comment is invisible. A line opening or closing a fenced code block
    (three backticks or tildes) toggles the fence and is itself not yielded;
    nothing inside a fence is yielded.
    """
    depth = 0
    fenced = False
    for number, line in enumerate(text.splitlines(), 1):
        out = []
        i = 0
        while i < len(line):
            if line.startswith(_COMMENT_OPEN, i):
                depth += 1
                i += len(_COMMENT_OPEN)
            elif depth and line.startswith(_COMMENT_CLOSE, i):
                depth -= 1
                i += len(_COMMENT_CLOSE)
            else:
                if not depth:
                    out.append(line[i])
                i += 1
        visible = "".join(out)
        if visible.lstrip().startswith(_FENCES):
            fenced = not fenced
            continue
        if fenced:
            continue
        yield number, visible


def read_status_header(text):
    """{field: (line, value)} from the first STATUS_HEADER_WINDOW lines.

    First occurrence of each field wins, and nothing below the window is
    read, so a mail body quoting an older header cannot fire.
    """
    header = {}
    for number, line in enumerate(text.splitlines()[:STATUS_HEADER_WINDOW], 1):
        match = _FIELD_RE.fullmatch(line)
        if match is not None and match.group(1) not in header:
            header[match.group(1)] = (number, match.group(2))
    return header


def _is_header_target(rel):
    """Outbound files minus the exempt README, OS metadata and binaries."""
    name = rel.rsplit("/", 1)[-1]
    if rel in EXEMPT_PATHS:
        return False
    if name in OS_METADATA_NAMES or name == GITKEEP:
        return False
    return os.path.splitext(name)[1].lower() not in BINARY_EXTS


def _dates_in(text):
    """Every real calendar date written YYYY-MM-DD in TEXT, in order."""
    found = []
    for match in _ISO_DATE_RE.finditer(text):
        if _is_real_date(*match.groups()):
            found.append(datetime.date(*(int(part) for part in match.groups())))
    return found


# ---------------------------------------------------------------------------
# COMMITMENTS AND UPCOMING ITEMS (D-03, D-12, D-13)
# ---------------------------------------------------------------------------


def _cited_outbound(source):
    """The first token of a bullet's trailing source naming an outbound/ file."""
    for token in source.split():
        if token.startswith(OUTBOUND_DIR + "/"):
            return token.rstrip(".,;")
    return None


def _cited_header(root, token, notes, where):
    """The status header of the outbound file TOKEN names, or None.

    Used only when the real path stays inside <root>/outbound/ and is a
    regular file that is not a symlink (T-06-11); otherwise a note says the
    citation could not be used and the caller falls back to the last date.
    """
    usable = None
    try:
        path = os.path.join(root, token)
        real = os.path.realpath(path)
        outdir = os.path.realpath(os.path.join(root, OUTBOUND_DIR))
        if (real.startswith(outdir + os.sep) and os.path.isfile(real)
                and not os.path.islink(path)):
            usable = real
    except (OSError, ValueError):
        usable = None
    text = read_text_safe(usable) if usable is not None else None
    if text is None:
        notes.append("{} cites {}, which is not a readable regular file inside {}/: "
                     "its last date is used instead".format(where, token, OUTBOUND_DIR))
        return None
    return read_status_header(text)


def _due_date(root, text, notes, where, dated_fallback=False):
    """The date a history bullet is due, or None when it is done or undated.

    D-13: a `done YYYY-MM-DD` marker before the source skips the line. D-12: a
    line whose source cites an outbound/ file takes that file's Deadline: and
    is skipped once that file is `sent` (an Upcoming bullet whose cited file has no
    Deadline: falls back to its last date); any other line is due on the LAST
    absolute date outside its trailing source.
    """
    match = _TRAILING_SOURCE_RE.search(text)
    before = text[:match.start()] if match else text
    source = match.group(1) if match else ""
    for done in _DONE_RE.finditer(before):
        if _is_real_date(*done.groups()):
            return None
    token = _cited_outbound(source)
    if token is not None:
        header = _cited_header(root, token, notes, where)
        if header is not None:
            status = header.get("Status")
            if status is not None and status[1].startswith("sent"):
                return None
            deadline = header.get("Deadline")
            if deadline is not None and is_absolute_date(deadline[1]):
                return _to_date(deadline[1])
            if not dated_fallback:
                return None
            # An Upcoming bullet may cite a call-prep file, which carries no
            # Deadline: by design (D-11): its own date is the one that counts.
    dates = _dates_in(before)
    return dates[-1] if dates else None


def commitments_and_upcoming(root, today, notes):
    """(commitments, upcoming) from dossier/HISTORY.md, by heading POSITION.

    Commitments are the bullets under the second `## ` heading, `ours` under
    its first `### ` and `theirs` under its second; upcoming items are the
    dated bullets under the third `## `. Positions, never titles, so a French
    dossier behaves the same without a word list.
    """
    rel = LIVING_DIR + "/HISTORY.md"
    text = read_text_safe(os.path.join(root, LIVING_DIR, "HISTORY.md"))
    if text is None:
        notes.append("{} is missing or unreadable: no commitments computed".format(rel))
        return [], []
    commitments = []
    upcoming = []
    h2 = 0
    h3 = 0
    side = None
    heading = None
    for number, line in visible_lines(text):
        if line.startswith("## "):
            h2 += 1
            h3 = 0
            side = None
            heading = None
            continue
        if h2 == 2 and line.startswith("### "):
            h3 += 1
            heading = line[4:].strip()
            side = "ours" if h3 == 1 else ("theirs" if h3 == 2 else None)
            continue
        body = line.strip()
        if not body.startswith(_BULLET_PREFIXES):
            continue
        bullet = body[2:].strip()
        where = "{}:{}".format(rel, number)
        if h2 == 2 and side is not None:
            due = _due_date(root, bullet, notes, where)
            if due is None:
                continue
            delta = (due - today).days
            if delta < 0:
                state = "overdue"
            elif delta <= SOON_DAYS:
                state = "due_soon"
            else:
                continue
            commitments.append({"file": rel, "line": number, "side": side,
                                "heading": heading, "date": due.isoformat(),
                                "state": state, "text": bullet})
        elif h2 == 3:
            due = _due_date(root, bullet, notes, where, dated_fallback=True)
            if due is None:
                continue
            if 0 <= (due - today).days <= SOON_DAYS:
                upcoming.append({"file": rel, "line": number,
                                 "date": due.isoformat(), "text": bullet})
    commitments.sort(key=lambda item: (item["date"], item["file"], item["line"]))
    upcoming.sort(key=lambda item: (item["date"], item["file"], item["line"]))
    return commitments, upcoming


def one_line_status(root, notes):
    """The first visible non-empty line under the first `## ` of RELATIONSHIP.md."""
    rel = LIVING_DIR + "/RELATIONSHIP.md"
    text = read_text_safe(os.path.join(root, LIVING_DIR, "RELATIONSHIP.md"))
    if text is None:
        notes.append("{} is missing or unreadable: no one-line status".format(rel))
        return None
    inside = False
    for _number, line in visible_lines(text):
        if line.startswith("## "):
            if inside:
                return None
            inside = True
            continue
        if not inside:
            continue
        body = line.strip()
        if not body:
            continue
        if body.startswith("#"):
            return None
        return body
    return None


# ---------------------------------------------------------------------------
# LIVING FILES: Last updated, staleness (D-05)
# ---------------------------------------------------------------------------


def read_staleness_days(root, notes):
    """The `staleness_days` of dossier.yaml, DEFAULT_STALENESS_DAYS when unusable."""
    text = read_text_safe(os.path.join(root, CONFIG_NAME))
    raw = None
    if text is not None and text.lstrip().startswith("{"):
        try:
            data = json.loads(text)
        except ValueError:
            data = None
        if isinstance(data, dict):
            raw = data.get("staleness_days")
            if isinstance(raw, bool):
                raw = None
            elif isinstance(raw, int):
                raw = str(raw)
            elif not isinstance(raw, str):
                raw = None
    elif text is not None:
        match = _STALENESS_RE.search(text)
        if match is not None:
            value = match.group(1).strip()
            if value[:1] in ("'", '"'):
                end = value.find(value[0], 1)
                raw = value[1:end] if end > 0 else None
            else:
                raw = re.sub(r"[ \t]+#.*$", "", value).strip()
    if raw is not None and re.fullmatch(r"[0-9]+", raw.strip()) and int(raw.strip()) >= 1:
        return int(raw.strip())
    notes.append("staleness_days is missing or not a whole number of at least 1 in {}: "
                 "using {}".format(CONFIG_NAME, DEFAULT_STALENESS_DAYS))
    return DEFAULT_STALENESS_DAYS


def living_dates(root, notes):
    """{relative path: date} of the first valid `Last updated:` of each living file."""
    dates = {}
    for name in LIVING_FILES:
        rel = LIVING_DIR + "/" + name
        text = read_text_safe(os.path.join(root, LIVING_DIR, name))
        if text is None:
            notes.append("{} is missing or unreadable".format(rel))
            continue
        for line in text.splitlines():
            match = _LAST_UPDATED_RE.match(line)
            if match is None:
                continue
            date = _DATE_PREFIX_RE.match(match.group(1))
            if date is not None and _is_real_date(*date.groups()):
                dates[rel] = datetime.date(*(int(part) for part in date.groups()))
            else:
                notes.append("{} has no valid Last updated: date".format(rel))
            break
        else:
            notes.append("{} has no Last updated: line".format(rel))
    return dates


def stale_files(dates, today, staleness_days, notes):
    """Living files last updated more than STALENESS_DAYS ago (future dates noted)."""
    stale = []
    for rel in sorted(dates):
        days = (today - dates[rel]).days
        if days < 0:
            notes.append("{} has Last updated: {} in the future".format(rel, dates[rel].isoformat()))
        elif days > staleness_days:
            stale.append({"path": rel, "last_updated": dates[rel].isoformat(), "days": days})
    stale.sort(key=lambda item: (item["last_updated"], item["path"]))
    return stale


# ---------------------------------------------------------------------------
# OVERDUE DRAFTS (D-05)
# ---------------------------------------------------------------------------


def _walk_files(root, folder):
    """POSIX paths (relative to ROOT) of the regular, non-symlink files under FOLDER."""
    found = []
    top = os.path.join(root, folder)
    if os.path.islink(top) or not os.path.isdir(top):
        return found
    for base, dirs, files in os.walk(top, followlinks=False):
        dirs.sort()
        for name in sorted(files):
            path = os.path.join(base, name)
            if os.path.islink(path) or not os.path.isfile(path):
                continue
            found.append(os.path.relpath(path, root).replace(os.sep, "/"))
    return found


def overdue_drafts(root, today):
    """Outbound files still `draft` or `reviewed by ...` past their Deadline:."""
    drafts = []
    for rel in _walk_files(root, OUTBOUND_DIR):
        if not _is_header_target(rel):
            continue
        text = read_text_safe(os.path.join(root, *rel.split("/")))
        if text is None:
            continue
        header = read_status_header(text)
        status = header.get("Status")
        deadline = header.get("Deadline")
        if status is None or deadline is None:
            continue
        value = status[1]
        if value != "draft" and not value.startswith("reviewed by"):
            continue
        if is_absolute_date(deadline[1]) and _to_date(deadline[1]) < today:
            drafts.append({"path": rel, "status": value, "deadline": deadline[1]})
    drafts.sort(key=lambda item: (item["deadline"], item["path"]))
    return drafts


# ---------------------------------------------------------------------------
# UNREFLECTED SOURCES (D-04, D-12)
# ---------------------------------------------------------------------------


def _git(root, args):
    """stdout bytes of a read-only git call, or None on any failure or timeout."""
    try:
        result = subprocess.run(
            ["git", "--no-optional-locks", "-c", "core.fsmonitor=false", "-C", root] + args,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=GIT_TIMEOUT,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if result.returncode != 0:
        return None
    return result.stdout


def _decode(raw):
    return raw.decode("utf-8", "surrogateescape")


def _git_paths(root, args):
    """The set of NUL-separated paths a git listing prints, None on failure."""
    out = _git(root, args)
    if out is None:
        return None
    return set(_decode(part) for part in out.split(b"\0") if part)


def _git_add_dates(root):
    """{path: date} of the LATEST add commit (author date) of each path under sources/."""
    out = _git(root, ["log", "--no-renames", "--relative", "--diff-filter=A",
                      "--name-only", "-z", "--format=@%at", "--", SOURCES_DIR])
    if out is None:
        return {}
    dates = {}
    stamp = None
    for token in _decode(out).split("\0"):
        if _GIT_STAMP_RE.fullmatch(token):
            try:
                stamp = datetime.date.fromtimestamp(int(token[1:]))
            except (OverflowError, OSError, ValueError):
                stamp = None
            continue
        if token.startswith("\n"):
            token = token[1:]
        if stamp is not None and token.startswith(SOURCES_DIR + "/") and token not in dates:
            dates[token] = stamp
    return dates


def unreflected_sources(root, today, last_reflected, notes):
    """Source files filed strictly after the newest `Last updated:` date.

    The filing date is the older of the add commit's author date and the
    file's mtime date (a commit made the day after filing is not a false
    positive); a file untracked or staged but never committed was filed today;
    an ignored file, or any file when git is unavailable, uses its mtime date.
    """
    files = []
    for rel in _walk_files(root, SOURCES_DIR):
        name = rel.rsplit("/", 1)[-1]
        if rel == SOURCES_DIR + "/" + README_NAME or name == GITKEEP or name in OS_METADATA_NAMES:
            continue
        files.append(rel)
    if not files:
        return []
    inside = _git(root, ["rev-parse", "--is-inside-work-tree"])
    in_repo = inside is not None and inside.strip() == b"true"
    added = {}
    fresh = set()
    if in_repo:
        added = _git_add_dates(root)
        untracked = _git_paths(root, ["ls-files", "--others", "--exclude-standard",
                                      "-z", "--", SOURCES_DIR])
        staged = _git_paths(root, ["diff", "--cached", "--name-only", "--diff-filter=A",
                                   "-z", "--", SOURCES_DIR])
        if untracked is None or staged is None:
            notes.append("git could not list the new files under {}/: some filing dates "
                         "may use file modification times".format(SOURCES_DIR))
        fresh = (untracked or set()) | (staged or set())
    else:
        notes.append("git is not available or {} is not inside a repository: filing dates "
                     "use file modification times".format(root))
    if last_reflected is None:
        notes.append("no living file carries a valid Last updated: date: every source "
                     "counts as not yet reflected")
    found = []
    for rel in files:
        try:
            mtime = datetime.date.fromtimestamp(os.lstat(os.path.join(root, *rel.split("/"))).st_mtime)
        except (OSError, OverflowError, ValueError):
            mtime = today
        if rel in added:
            filed = min(added[rel], mtime)
            how = "git"
        elif rel in fresh:
            filed = today
            how = "untracked"
        else:
            filed = mtime
            how = "mtime"
        if last_reflected is None or filed > last_reflected:
            found.append({"path": rel, "filed": filed.isoformat(), "how": how})
    found.sort(key=lambda item: (item["filed"], item["path"]))
    return found


# ---------------------------------------------------------------------------
# LINT (D-02, D-12)
# ---------------------------------------------------------------------------


def _lint_result(available, exit_code=None, errors=None, warnings=None, findings=None, info=None):
    return {"available": available, "exit": exit_code, "errors": errors,
            "warnings": warnings, "findings": findings or [], "info": info or []}


def run_lint(root, lint_arg, notes):
    """Run the linter as a subprocess and parse its report.

    The linter is --lint PATH when given, else scripts/lint.py of the
    repository holding this script. Never found through a shell
    variable (T-06-10), never imported.
    """
    if lint_arg:
        lint_path = Path(lint_arg)
    else:
        lint_path = Path(__file__).resolve().parents[3] / "scripts" / "lint.py"
    if not lint_path.is_file():
        return _lint_result(False)
    try:
        result = subprocess.run(
            [sys.executable or "python3", "-I", "-B", str(lint_path), root],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=LINT_TIMEOUT,
        )
    except subprocess.TimeoutExpired:
        notes.append("lint could not run: it did not finish within {} seconds".format(LINT_TIMEOUT))
        return _lint_result(True)
    except OSError as exc:
        notes.append("lint could not run: {}".format(type(exc).__name__))
        return _lint_result(True)
    if result.returncode not in (0, 1):
        notes.append("lint could not run: it exited with status {}".format(result.returncode))
        return _lint_result(True, exit_code=result.returncode)
    findings = []
    info = []
    errors = None
    warnings = None
    for line in result.stdout.decode("utf-8", "replace").splitlines():
        summary = _LINT_SUMMARY_RE.fullmatch(line)
        if summary is not None:
            errors = int(summary.group(1))
            warnings = int(summary.group(2))
            continue
        if line.startswith("info: "):
            info.append(line[len("info: "):])
            continue
        match = _LINT_FINDING_RE.fullmatch(line)
        if match is not None:
            findings.append({"path": match.group(1), "line": int(match.group(2)),
                             "severity": match.group(3), "id": match.group(4),
                             "message": match.group(5)})
    if errors is None:
        notes.append("lint printed no summary line: its counts are unknown")
    return _lint_result(True, exit_code=result.returncode, errors=errors,
                        warnings=warnings, findings=findings, info=info)


# ---------------------------------------------------------------------------
# REPORT
# ---------------------------------------------------------------------------


def emit_json(report):
    print(json.dumps(report, ensure_ascii=True, indent=2))


def _commitment_line(item):
    return "- {}: ({}, {}) {} [{}:{}]".format(
        item["date"], item["side"], item["heading"], item["text"], item["file"], item["line"])


def emit_text(report):
    lines = []
    lines.append("Dossier: {}".format(report["root"]))
    lines.append("Today: {}".format(report["today"]))
    lines.append("One-line status: {}".format(report["status_line"] or "none recorded"))

    def section(title, items, render):
        lines.append("")
        lines.append(title)
        if items:
            lines.extend(render(item) for item in items)
        else:
            lines.append("- none")

    overdue = [item for item in report["commitments"] if item["state"] == "overdue"]
    soon = [item for item in report["commitments"] if item["state"] == "due_soon"]
    section("Commitments overdue:", overdue, _commitment_line)
    section("Commitments due within {} days:".format(SOON_DAYS), soon, _commitment_line)
    section("Upcoming within {} days:".format(SOON_DAYS), report["upcoming"],
            lambda item: "- {}: {} [{}:{}]".format(item["date"], item["text"], item["file"], item["line"]))
    section("Overdue drafts:", report["overdue_drafts"],
            lambda item: "- {}: {}, deadline {}".format(item["path"], item["status"], item["deadline"]))
    section("Sources not yet reflected (newest Last updated: {}):".format(
        report["last_reflected"] or "none"), report["unreflected_sources"],
        lambda item: "- {}: filed {} ({})".format(item["path"], item["filed"], item["how"]))
    section("Stale living files (staleness_days {}):".format(report["staleness_days"]),
            report["stale_files"],
            lambda item: "- {}: last updated {} ({} days ago)".format(
                item["path"], item["last_updated"], item["days"]))
    lint = report["lint"]
    lines.append("")
    if not lint["available"]:
        lines.append("Lint: unavailable")
    elif lint["errors"] is None:
        lines.append("Lint: did not run (see notes)")
    else:
        lines.append("Lint: {} error(s), {} warning(s)".format(lint["errors"], lint["warnings"]))
        for finding in lint["findings"]:
            lines.append("- {}:{}: {} [{}] {}".format(
                finding["path"], finding["line"], finding["severity"], finding["id"], finding["message"]))
        for text in lint["info"]:
            lines.append("- info: {}".format(text))
    if report["notes"]:
        lines.append("")
        lines.append("Notes:")
        lines.extend("- {}".format(note) for note in report["notes"])
    for line in lines:
        print(sanitise_path(line))


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def _today_arg(value):
    if _TODAY_RE.fullmatch(value) is None or not is_absolute_date(value):
        raise argparse.ArgumentTypeError("expected a real calendar date YYYY-MM-DD, got {!r}".format(value))
    return _to_date(value)


def build_parser():
    parser = argparse.ArgumentParser(
        description="Report the status of a client-dossier repository (mechanics tier; "
        "read-only, never fixes anything).",
        epilog=(
            "The dossier root is the nearest folder holding dossier.yaml, found by walking "
            "upward from PATH. Exit codes: 0 report printed, 2 no dossier.yaml found upward, "
            "path missing, dossier.yaml unreadable or invalid arguments, 3 internal error."
        ),
    )
    parser.add_argument("path", nargs="?", default=".",
                        help="A path inside the dossier (default: the current directory).")
    parser.add_argument("--json", action="store_true", dest="as_json",
                        help="Print one ASCII-only JSON object instead of text.")
    parser.add_argument("--today", type=_today_arg, default=None, metavar="YYYY-MM-DD",
                        help="The date to compute the report for (default: today).")
    parser.add_argument("--lint", default=None, metavar="PATH",
                        help="The linter to run (default: scripts/lint.py of this repository).")
    return parser


def _run(args):
    start = args.path
    if not os.path.exists(start):
        print("error: no such file or directory: {}".format(start), file=sys.stderr)
        return EXIT_NO_DOSSIER
    root = find_root(start)
    if root is None:
        print("error: no dossier.yaml found from {} upward".format(os.path.realpath(start)),
              file=sys.stderr)
        return EXIT_NO_DOSSIER
    if read_text_safe(os.path.join(root, CONFIG_NAME)) is None:
        print("error: cannot read {} (not a regular UTF-8 file under 5 MB)".format(
            os.path.join(root, CONFIG_NAME)), file=sys.stderr)
        return EXIT_NO_DOSSIER
    today = args.today if args.today is not None else datetime.date.today()
    notes = []
    dates = living_dates(root, notes)
    last_reflected = max(dates.values()) if dates else None
    staleness_days = read_staleness_days(root, notes)
    commitments, upcoming = commitments_and_upcoming(root, today, notes)
    report = {
        "root": root,
        "today": today.isoformat(),
        "status_line": one_line_status(root, notes),
        "commitments": commitments,
        "upcoming": upcoming,
        "last_reflected": last_reflected.isoformat() if last_reflected else None,
        "unreflected_sources": unreflected_sources(root, today, last_reflected, notes),
        "overdue_drafts": overdue_drafts(root, today),
        "stale_files": stale_files(dates, today, staleness_days, notes),
        "staleness_days": staleness_days,
        "lint": run_lint(root, args.lint, notes),
        "notes": notes,
    }
    if args.as_json:
        emit_json(report)
    else:
        emit_text(report)
    return EXIT_OK


def _tolerant_streams():
    """Escape, never raise on, a character the console cannot encode."""
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(errors="backslashreplace")
        except (AttributeError, ValueError):
            pass


def main(argv=None):
    _tolerant_streams()
    args = build_parser().parse_args(argv)
    try:
        return _run(args)
    except Exception as exc:  # never masquerade as "this dossier is fine"
        print("error: internal status failure: {}: {}".format(type(exc).__name__, exc), file=sys.stderr)
        return EXIT_INTERNAL


if __name__ == "__main__":
    sys.exit(main())
