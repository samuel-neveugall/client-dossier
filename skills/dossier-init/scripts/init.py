#!/usr/bin/env python3
# vibeflow:allow-large-file -- mechanics-tier scaffold script; grew past the
# 300-line guard when plan 01-02 wired the eleven remaining templates and
# resolve_template_dir(). Splitting deferred: TEMPLATE_MAP, the write loop
# and the variant resolution are one cohesive scaffold pass (plan 01-01's
# established pattern). Tracked in 01-02-SUMMARY.md and .planning/WINDOWS.md.
"""Scaffold a client-dossier repository.

Mechanics tier only (spec principle: "skills carry the judgement, scripts
carry the mechanics"). Every input arrives as a command-line argument — this
script never prompts, never reads a TTY, and never shells out. Judgement
(the grouped question, language inference, rename detection, translation)
lives in skills/dossier-init/SKILL.md.

Python 3 standard library only, targeting Python >= 3.8.
"""

import argparse
import datetime
import os
import re
import shlex
import subprocess
import sys
from pathlib import Path

# The twelve directories the scaffold creates (spec Sec3.2).
FOLDERS = (
    "sources",
    "sources/received",
    "sources/transcripts",
    "sources/transcripts/raw",
    "dossier",
    "knowledge",
    "knowledge/decisions",
    "knowledge/watch",
    "outbound",
    "outbound/deliverables",
    "outbound/mails",
    "outbound/calls",
)

# The seven leaves spec Sec3.2 names verbatim. Git does not track empty
# folders, so each gets a .gitkeep, written unconditionally (never "if
# empty") -- an adopted repository can hold a folder that is empty today but
# never survived a clone, and after an adoption rename a "leaf" may already
# hold a file.
GITKEEP_LEAVES = (
    "sources/received",
    "sources/transcripts/raw",
    "knowledge/decisions",
    "knowledge/watch",
    "outbound/deliverables",
    "outbound/mails",
    "outbound/calls",
)

# Ordered mapping: bundled template filename -> target path under the
# dossier root. Order matches spec Sec3.2 scaffold order, so the report
# reads top-down: the seven living files, the two knowledge stubs, then
# the three folder READMEs (each renamed to README.md at its target).
TEMPLATE_MAP = {
    "ACTORS.md": "dossier/ACTORS.md",
    "HISTORY.md": "dossier/HISTORY.md",
    "LEARNINGS.md": "dossier/LEARNINGS.md",
    "TONE.md": "dossier/TONE.md",
    "CHANNELS.md": "dossier/CHANNELS.md",
    "OPEN-QUESTIONS.md": "dossier/OPEN-QUESTIONS.md",
    "RELATIONSHIP.md": "dossier/RELATIONSHIP.md",
    "CONTEXT.md": "knowledge/CONTEXT.md",
    "DOCTRINE.md": "knowledge/DOCTRINE.md",
    "README-dossier.md": "dossier/README.md",
    "README-sources.md": "sources/README.md",
    "README-outbound.md": "outbound/README.md",
}

# The line a rendered living-file template carries before substitution.
_LAST_UPDATED_RE = re.compile(r"^(Last updated:[ \t]*)YYYY-MM-DD[ \t]*$", re.MULTILINE)

# The two marker comments delimiting the protocol-pointer section this
# script upserts into AGENTS.md and CLAUDE.md (D-16, SCAF-05). Anchors, not
# prose: every future run and every future revision of the pointer body
# keys off these two exact strings, so they live here once, as module-level
# constants, and nowhere else in this file.
MARKER_START = "<!-- client-dossier:start -->"
MARKER_END = "<!-- client-dossier:end -->"

# One-way adoption table (SCAF-06, D-14): used once by propose_renames()
# below, at init time, and never as a runtime name mapping (CLAUDE.md C-3
# -- fixed English names everywhere else). Every key is matched
# case-insensitively; every emitted value is the fixed English literal,
# verbatim. Three groups, looked up in that order:
#
# - "top": the four top-level roles, matched against an immediate
#   subdirectory of the repository root.
# - "child_dir": subdirectory names, matched only one level inside a
#   directory that "top" already mapped -- includes the fixed English name
#   as its own key (e.g. "calls" -> "calls", "received" -> "received") so
#   an already-correctly-named child recurses to "nothing to propose"
#   rather than falling through to the sources-only ignored rule or (for
#   any other mapped parent) being silently skipped.
# - "child_file": living-file names, matched only one level inside a
#   directory that "top" already mapped. Deliberately has no self-mapping
#   entries: a file already carrying its fixed English name (or any file
#   with no role, such as README.md) is not in this table, so the lookup
#   misses and propose_renames() emits nothing for it (D-14's "a proposal
#   only ever contains work to do").
RENAME_TABLE = {
    "top": {
        "dossier": "dossier",
        "client": "dossier",
        "relation": "dossier",
        "relationship": "dossier",
        "knowledge": "knowledge",
        "docs": "knowledge",
        "connaissance": "knowledge",
        "connaissances": "knowledge",
        "outbound": "outbound",
        "communication": "outbound",
        "sortant": "outbound",
        "sources": "sources",
    },
    "child_dir": {
        "appels": "calls",
        "calls": "calls",
        "livrables": "deliverables",
        "deliverables": "deliverables",
        "mails": "mails",
        "veille": "watch",
        "watch": "watch",
        "decisions": "decisions",
        "transcripts": "transcripts",
        "raw": "raw",
        # Not in D-14's own enumeration, but required for the same reason
        # every other already-correct child is listed here: without a
        # self-mapping entry, a freshly scaffolded sources/received/
        # (spec Sec3.2's own fixed name, created by FOLDERS above) would
        # fall through to the sources-only "unmapped subfolder" ignored
        # rule on a re-run, contradicting D-08's idempotence guarantee.
        "received": "received",
    },
    "child_file": {
        "acteurs.md": "ACTORS.md",
        "apprentissages.md": "LEARNINGS.md",
        "canaux.md": "CHANNELS.md",
        "historique.md": "HISTORY.md",
        "questions-ouvertes.md": "OPEN-QUESTIONS.md",
        "relation.md": "RELATIONSHIP.md",
        "ton.md": "TONE.md",
        "contexte.md": "CONTEXT.md",
    },
}

# The living-file content hint (D-14): a directory whose name matches
# nothing in RENAME_TABLE["top"] but that holds at least two of these
# names (either language) looks like a dossier/ that was never renamed
# into the table -- reported as a "candidate:" line for a human to
# confirm, never proposed outright.
LIVING_FILE_HINT_NAMES = frozenset(
    name.lower()
    for name in (
        "ACTEURS.md", "APPRENTISSAGES.md", "CANAUX.md", "HISTORIQUE.md",
        "QUESTIONS-OUVERTES.md", "RELATION.md", "TON.md",
        "ACTORS.md", "LEARNINGS.md", "CHANNELS.md", "HISTORY.md",
        "OPEN-QUESTIONS.md", "RELATIONSHIP.md", "TONE.md",
    )
)


class MarkerSectionError(Exception):
    """The target's marker pair is ambiguous or malformed.

    Raised instead of guessing: a start marker with no end (or two of
    either), or an end marker before a start, could mean the span was hand-
    edited into an unrecognisable shape. Guessing where it begins or ends
    risks deleting a person's own instructions file.
    """


def yaml_quote(value):
    """Return a double-quoted YAML scalar, safe for any user-supplied string.

    Strips every character below 0x20 (newlines included), then escapes
    backslashes and double quotes -- in that order, so a backslash inserted
    by the first escape is never re-escaped by the second.
    """
    cleaned = "".join(ch for ch in value if ord(ch) >= 0x20)
    cleaned = cleaned.replace("\\", "\\\\").replace('"', '\\"')
    return '"' + cleaned + '"'


# T-01-01 requires every scalar fed by user input to pass through
# yaml_quote() -- but round 2 of security review found two CLI-fed fields
# (`language`, `status_header`) that were emitted as bare, unquoted plain
# scalars instead. The narrow fix (quote those two lines) treats the
# symptom; the actual cause is that render_dossier_yaml() had two ways to
# emit a scalar -- quoted (yaml_quote(), used everywhere else) and raw
# (str.format() straight onto the line) -- and nothing stopped a future
# field from picking the wrong one.
#
# emit_scalar() removes that second way for values whose nominal shape is a
# short bare identifier (a language code, `required`): it emits the value
# unquoted -- byte-identical to today's output -- only when it matches
# _SAFE_PLAIN_SCALAR_RE (letters/digits/underscore/hyphen, first character a
# letter); anything else, including every injection payload demonstrated
# against `--language`/`--status-header` this round, falls through to
# yaml_quote() instead of ever reaching the file unescaped. This is an
# allowlist, not a blocklist: a value needs no denylist of "dangerous"
# characters to be rejected into the quoted path, it just needs to not look
# like a bare identifier.
_SAFE_PLAIN_SCALAR_RE = re.compile(r"^[A-Za-z][A-Za-z0-9_-]*$")


def emit_scalar(key, value):
    """Return `key: value`, safe for any user-supplied string in `value`.

    Emits an unquoted YAML plain scalar when `value` matches
    _SAFE_PLAIN_SCALAR_RE (preserving today's nominal output byte for byte),
    otherwise routes through yaml_quote() -- the same escaping every other
    free-text field in this file already goes through.
    """
    text = value if _SAFE_PLAIN_SCALAR_RE.match(value) else yaml_quote(value)
    return "{}: {}".format(key, text)


def parse_counterpart(spec):
    """Parse `NAME|ROLE|CONTACT;CONTACT` into a dict.

    Role and contacts are optional. A missing field becomes empty and is
    then omitted from the returned dict entirely -- never written blank.
    """
    parts = spec.split("|")
    name = parts[0].strip() if len(parts) > 0 else ""
    role = parts[1].strip() if len(parts) > 1 else ""
    contacts_field = parts[2] if len(parts) > 2 else ""

    entry = {"name": name}
    if role:
        entry["role"] = role
    if contacts_field:
        contacts = [c.strip() for c in contacts_field.split(";") if c.strip()]
        if contacts:
            entry["contacts"] = contacts
    return entry


def render_dossier_yaml(cfg):
    """Emit dossier.yaml's ten spec Sec3.2 keys, in spec order.

    Emission only -- this script never parses YAML. Parsing an existing
    dossier.yaml is Phase 2's problem, with the tiny YAML-subset parser the
    spec already prescribes.
    """
    lines = ["# dossier.yaml", "version: 1", emit_scalar("language", cfg["language"]), "counterparts:"]

    for counterpart in cfg["counterparts"]:
        lines.append("  - name: {}".format(yaml_quote(counterpart["name"])))
        if "role" in counterpart:
            lines.append("    role: {}".format(yaml_quote(counterpart["role"])))
        if "contacts" in counterpart:
            quoted = ", ".join(yaml_quote(c) for c in counterpart["contacts"])
            lines.append("    contacts: [ {} ]".format(quoted))

    confidential_names = cfg["confidential_names"]
    if confidential_names:
        quoted_names = ", ".join(yaml_quote(n) for n in confidential_names)
        lines.append("confidential_names: [ {} ]".format(quoted_names))
    else:
        lines.append("confidential_names: []")

    lines.append("consent_recorded: {}".format("true" if cfg["consent_recorded"] else "false"))
    lines.append("consent_source: {}".format(yaml_quote(cfg["consent_source"])))
    lines.append("timestamps: {}".format(yaml_quote(cfg["timestamps"])))
    lines.append("date_format: {}".format(yaml_quote(cfg["date_format"])))
    lines.append(emit_scalar("status_header", cfg["status_header"]))
    lines.append("staleness_days: {}".format(cfg["staleness_days"]))

    return "\n".join(lines) + "\n"


def render_template(text, today):
    """Substitute today's date on the `Last updated:` line only.

    Anchored to that exact line so the same YYYY-MM-DD token appearing
    elsewhere in a template body (a status-header illustration, for
    instance) survives verbatim.
    """
    return _LAST_UPDATED_RE.sub(lambda m: m.group(1) + today, text)


def under_root(root, path):
    """True when the resolved `path` is `root` or lives under it."""
    resolved_root = os.path.realpath(root)
    resolved_path = os.path.realpath(path)
    return os.path.commonpath([resolved_root, resolved_path]) == resolved_root


def resolve_template_dir(templates_root, language, variant, required_names):
    """Decide which templates/<name>/ directory to scaffold from (D-09).

    `required_names` lists the template filenames that must all be present
    as regular files under a candidate directory for it to count as usable.
    A directory that merely exists but is missing one of them -- a variant
    translated file by file, or (in this repository, mid-phase) a sibling
    plan's templates not yet landed on this branch -- is treated exactly
    like a variant that does not exist at all, and falls back the same way.
    This is what lets one function resolve both the twelve-file scaffold
    body and the single-file AGENTS-pointer.md pointer independently from
    the same --language/--template-variant pair, without ever splicing two
    languages into one written file.

    - an explicit `variant` wins outright. If `templates_root/<variant>/`
      does not exist (or would resolve outside `templates_root`), or is
      missing any name in `required_names`, the caller must report the
      name on stderr and exit before writing anything -- this function
      signals that case by returning `None` as the first element.
    - otherwise, if `templates_root/<language>/` exists and holds every
      name in `required_names`, use it.
    - otherwise fall back to `templates_root/en/`, and say so: the caller
      prints the fallback note as part of the `templates: <variant>`
      report line, which is the mechanical handoff to the skill's
      translation step (SCAF-07) -- this script never translates anything.

    Returns (path_or_none, report_variant, fallback_note_or_none).
    """

    def has_all_required(candidate_dir):
        return all((candidate_dir / name).is_file() for name in required_names)

    if variant:
        variant_dir = templates_root / variant
        if (
            not under_root(templates_root, variant_dir)
            or not variant_dir.is_dir()
            or not has_all_required(variant_dir)
        ):
            return None, variant, None
        return variant_dir, variant, None

    language_dir = templates_root / language
    if (
        under_root(templates_root, language_dir)
        and language_dir.is_dir()
        and has_all_required(language_dir)
    ):
        return language_dir, language, None

    fallback_note = (
        "requested language {!r} has no template variant; scaffolded from "
        "templates/en/ -- translate the created files".format(language)
    )
    return templates_root / "en", "en", fallback_note


def write_if_missing(path, text):
    """Write `text` to `path` only if it does not already exist.

    Returns "created" or "kept". Never opens an existing path for writing --
    no truncation, no overwrite, no merge. This is D-08, the single control
    that stops a re-run from destroying a living dossier.
    """
    if os.path.exists(path):
        return "kept"
    parent = os.path.dirname(path)
    if parent:
        os.makedirs(parent, exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(text)
    return "created"


def upsert_marker_section(path, body):
    """Create, append, or in-place-update the marker-delimited section at `path`.

    Returns "created", "appended", "updated", or "unchanged". This is the
    one write path in this script that does not go through
    write_if_missing(), and that is deliberate: `path` may already exist
    without the section, so "skip because it exists" (D-08's rule
    everywhere else) would silently do nothing here (RESEARCH Pitfall 7).

    - target absent -> "created": the file is written containing the start
      marker, the body, the end marker, and nothing else.
    - target exists, zero of each marker -> "appended": the block is added
      after the existing content, separated by one blank line; every
      pre-existing byte is preserved.
    - target exists, exactly one of each marker, start before end ->
      "updated" (or "unchanged" when the new text is byte-identical to the
      old, which is what makes a second identical run a no-op): only the
      span from the start marker through the end marker inclusive is
      replaced; the text before and after is preserved byte for byte.
    - any other marker count, or an end marker before a start marker ->
      raises MarkerSectionError naming `path`, having written nothing to
      it. Guessing where an ambiguous section begins or ends could delete
      a person's own instructions.
    """
    block = MARKER_START + "\n" + body.strip() + "\n" + MARKER_END + "\n"

    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as handle:
            existing = handle.read()
    else:
        existing = None

    if existing is None:
        new_text = block
        result = "created"
    else:
        start_count = existing.count(MARKER_START)
        end_count = existing.count(MARKER_END)

        if start_count == 0 and end_count == 0:
            new_text = existing + "\n" + block
            result = "appended"
        elif start_count == 1 and end_count == 1:
            start_index = existing.index(MARKER_START)
            end_index = existing.index(MARKER_END)
            if end_index < start_index:
                raise MarkerSectionError(
                    "{}: end marker appears before start marker".format(path)
                )
            span_end = end_index + len(MARKER_END)
            # Consume a single trailing newline after the end marker, if
            # present, so re-splicing does not grow a blank line on every
            # update.
            if span_end < len(existing) and existing[span_end] == "\n":
                span_end += 1
            new_text = existing[:start_index] + block + existing[span_end:]
            result = "updated"
        else:
            raise MarkerSectionError(
                "{}: ambiguous marker section ({} start, {} end) -- refusing "
                "to guess where it begins or ends".format(path, start_count, end_count)
            )

        if new_text == existing:
            return "unchanged"

    parent = os.path.dirname(path)
    if parent:
        os.makedirs(parent, exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(new_text)
    return result


def _git_repo_available(root):
    """True when `git` is on PATH and `root` is inside a git work tree.

    Never raises: a missing `git` binary or a non-repository target is a
    fact about the environment, not a bug to crash on (CLAUDE.md C-8).
    """
    try:
        result = subprocess.run(
            ["git", "-C", root, "rev-parse", "--is-inside-work-tree"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except (FileNotFoundError, OSError):
        return False
    return result.returncode == 0 and result.stdout.strip() == b"true"


def _git_tracked(root, relpath):
    """True when `git ls-files` finds a tracked path matching `relpath`.

    Run through subprocess.run() with an argument list and shell=False --
    never a shell string (T-01-22). `relpath` is passed after `--` so a
    name that happens to start with `-` is never read as an option.
    """
    try:
        result = subprocess.run(
            ["git", "-C", root, "ls-files", "--error-unmatch", "--", relpath],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except (FileNotFoundError, OSError):
        return False
    return result.returncode == 0


def _content_hint_role(dir_path):
    """Return "dossier" when `dir_path` holds >=2 known living-file names.

    The only content hint D-14 defines. Returns None on a listing error
    (e.g. a directory that vanished or is unreadable between the parent
    scan and this call) rather than raising.
    """
    try:
        names = os.listdir(dir_path)
    except OSError:
        return None
    hits = sum(1 for name in names if name.lower() in LIVING_FILE_HINT_NAMES)
    return "dossier" if hits >= 2 else None


def propose_renames(root):
    """Build the read-only `--propose-renames` report for `root` (SCAF-06).

    Pure inspection: reads the filesystem and runs `git`, and never writes,
    creates or moves anything (T-01-24). Returns the full report as one
    string, newline-terminated, ready to print verbatim.

    For each immediate subdirectory of `root` (dotfiles/dirs such as `.git`
    skipped outright -- never a rename candidate):

    - resolve it with os.path.realpath; a result outside the resolved root
      becomes an "unsafe:" entry and nothing else is done with it
      (T-01-23; RESEARCH/CONTEXT symlink-escape case).
    - look its name up in RENAME_TABLE["top"] (case-insensitive). A hit
      that already equals its target emits nothing for the directory
      itself but still recurses into it; a hit that differs is a rename
      candidate.
    - a miss is examined for the living-file content hint: >=2 hits
      becomes a "candidate:" entry (reported for a human to confirm,
      never proposed); no hint becomes an "ignored:" entry with the
      no-role reason.
    - inside a directory the top-level table mapped, apply
      RENAME_TABLE["child_dir"] and RENAME_TABLE["child_file"] to its
      immediate children, one level deep. A child directory the table
      does not name becomes an "ignored:" entry naming the spec-layout
      reason only when the mapped parent is "sources" (RESEARCH DISC-1,
      decided in 01-05-PLAN.md's Deviations, not D-14's own enumeration);
      inside any other mapped parent, an unmapped child (directory or
      file) is silently skipped -- exactly like DOCTRINE.md or README.md,
      which already carry their fixed English names and so are not in
      RENAME_TABLE["child_file"] at all.
    - every rename candidate (top-level or child) is probed with
      `git ls-files --error-unmatch` before being proposed; untracked
      moves the entry to the untracked section instead, arrow kept, with
      the history warning appended (T-01-25, RESEARCH Pitfall 6, O-2).
      When `git` itself is unusable against `root`, every candidate that
      would otherwise be a rename is treated as untracked instead, and a
      single note says so once, rather than probing (and failing) once
      per candidate.

    Path composition follows the proposal's own execution order: a child
    path is printed against its parent's *new* name, not the name still on
    disk, so the printed list can be applied top to bottom (the docstring
    on the "knowledge/veille" case in tests/golden/adopt-proposal.txt is
    the worked example). `git` is always probed against the real on-disk
    relative path, which is tracked under the *old* name until the rename
    actually runs.

    Every printed path passes through shlex.quote() (T-01-22): the mode
    never builds a shell string itself, but this proposal is what the
    skill will later splice into a `git mv -- <old> <new>` call.

    Emission order: the summary line, then "rename:" (grouped by top-level
    candidate in lexicographic order of the *original* name, the top-level
    line first in its group, children sorted lexicographically after it),
    then "untracked:", then "unsafe:", then "candidate:", then "ignored:"
    -- each of those last four sorted lexicographically. This is the
    entire acceptance surface of tests/golden/adopt-proposal.txt: two runs
    on the same tree must produce identical bytes.
    """
    resolved_root = os.path.realpath(root)
    git_ok = _git_repo_available(resolved_root)

    top_table = RENAME_TABLE["top"]
    child_dir_table = RENAME_TABLE["child_dir"]
    child_file_table = RENAME_TABLE["child_file"]

    renames = []  # (group_key, rank, subkey, old, new) -- rank 0 = the top-level line itself
    untracked = []  # (old, new)
    unsafe = []  # (name,)
    candidates = []  # (name, role)
    ignored = []  # (old, reason)
    git_unusable_noted = [False]

    def propose_or_untrack(disk_relpath, old, new, group_key, rank, subkey):
        tracked = git_ok and _git_tracked(resolved_root, disk_relpath)
        if tracked:
            renames.append((group_key, rank, subkey, old, new))
        else:
            if not git_ok and not git_unusable_noted[0]:
                git_unusable_noted[0] = True
            untracked.append((old, new))

    try:
        top_entries = sorted(os.listdir(resolved_root))
    except OSError:
        top_entries = []

    for name in top_entries:
        if name.startswith("."):
            # Never a dossier role, and this is what keeps .git itself out
            # of the scan -- it is not a rename candidate under any table.
            continue

        disk_path = os.path.join(resolved_root, name)
        if not os.path.isdir(disk_path):
            continue

        real_child = os.path.realpath(disk_path)
        if not under_root(resolved_root, real_child):
            unsafe.append(name)
            continue

        target = top_table.get(name.lower())
        if target is None:
            role = _content_hint_role(disk_path)
            if role:
                candidates.append((name, role))
            else:
                ignored.append((name, "no dossier role"))
            continue

        if target != name:
            propose_or_untrack(name, name, target, name, 0, "")

        try:
            child_names = sorted(os.listdir(disk_path))
        except OSError:
            child_names = []

        for child_name in child_names:
            child_disk_path = os.path.join(disk_path, child_name)
            child_disk_relpath = os.path.join(name, child_name)
            printed_old = "{}/{}".format(target, child_name)

            if os.path.isdir(child_disk_path):
                real_grandchild = os.path.realpath(child_disk_path)
                if not under_root(resolved_root, real_grandchild):
                    unsafe.append(printed_old)
                    continue
                child_target = child_dir_table.get(child_name.lower())
                if child_target is None:
                    if target == "sources":
                        ignored.append((
                            printed_old,
                            "source subfolders are never renamed; "
                            "sources/received/ is created empty",
                        ))
                    continue
                if child_target == child_name:
                    continue
                printed_new = "{}/{}".format(target, child_target)
                propose_or_untrack(
                    child_disk_relpath, printed_old, printed_new, name, 1, child_name
                )
            else:
                file_target = child_file_table.get(child_name.lower())
                if file_target is None:
                    continue
                printed_new = "{}/{}".format(target, file_target)
                propose_or_untrack(
                    child_disk_relpath, printed_old, printed_new, name, 1, child_name
                )

    renames.sort(key=lambda item: (item[0], item[1], item[2]))
    untracked.sort(key=lambda item: item[0])
    unsafe.sort()
    candidates.sort(key=lambda item: item[0])
    ignored.sort(key=lambda item: item[0])

    lines = [
        "propose-renames: {} proposed, {} untracked, {} unsafe, {} ignored".format(
            len(renames), len(untracked), len(unsafe), len(ignored)
        )
    ]
    if git_unusable_noted[0]:
        lines.append(
            "note: git is unavailable or {} is not a repository -- every "
            "rename candidate is reported as untracked".format(shlex.quote(root))
        )
    for _group, _rank, _subkey, old, new in renames:
        lines.append("rename: {} -> {}".format(shlex.quote(old), shlex.quote(new)))
    for old, new in untracked:
        lines.append(
            "untracked: {} -> {} (not tracked by git - would be moved with "
            "plain mv, history not preserved)".format(shlex.quote(old), shlex.quote(new))
        )
    for name in unsafe:
        lines.append(
            "unsafe: {} (resolves outside the repository root; refusing to "
            "propose a rename)".format(shlex.quote(name))
        )
    for name, role in candidates:
        lines.append(
            "candidate: {} -> {} (holds known {} files; confirm before "
            "renaming)".format(shlex.quote(name), role, role)
        )
    for old, reason in ignored:
        lines.append("ignored: {} ({})".format(shlex.quote(old), reason))

    return "\n".join(lines) + "\n"


def build_parser():
    parser = argparse.ArgumentParser(
        description="Scaffold a client-dossier repository (mechanics tier; never interactive)."
    )
    parser.add_argument("--target", default=".", help="Path to the repository to scaffold.")
    parser.add_argument("--language", default="en", help="Dossier content language code.")
    parser.add_argument(
        "--template-variant",
        default=None,
        help="Force a specific templates/<name>/ directory, overriding --language resolution.",
    )
    parser.add_argument(
        "--counterpart",
        action="append",
        default=[],
        help="NAME|ROLE|CONTACT;CONTACT (role and contacts optional). Repeatable.",
    )
    parser.add_argument(
        "--confidential-name",
        dest="confidential_names",
        action="append",
        default=[],
        help="A name never allowed under outbound/. Repeatable.",
    )
    parser.add_argument("--consent-recorded", choices=["true", "false"], default="false")
    parser.add_argument("--consent-source", default="")
    parser.add_argument("--timestamps", default="@mm:ss")
    parser.add_argument("--date-format", default="YYYY-MM-DD")
    # "required" is the only value spec Sec3.2 ever documents for this key;
    # constraining it here is a second, independent line of defense next to
    # emit_scalar()'s allowlist -- it never touches the non-interactive
    # contract, since the default already is the sole allowed choice.
    parser.add_argument("--status-header", default="required", choices=["required"])
    parser.add_argument("--staleness-days", type=int, default=7)
    parser.add_argument(
        "--propose-renames",
        action="store_true",
        help=(
            "Print a read-only adoption rename proposal for --target and exit "
            "(SCAF-06, D-14/D-15); writes nothing, even combined with a "
            "scaffolding flag."
        ),
    )
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)

    target_root = os.path.realpath(args.target)
    if not os.path.isdir(target_root):
        print("error: --target {!r} is not a directory".format(args.target), file=sys.stderr)
        return 1

    # --propose-renames is a read-only mode: it returns before any write
    # path below runs, even when combined with a scaffolding flag (D-15 --
    # the skill executes git mv only after a human confirms; this script
    # never executes it and never writes here).
    if args.propose_renames:
        sys.stdout.write(propose_renames(target_root))
        return 0

    # Resolve the template variant before any write, so an unknown
    # --template-variant aborts having written nothing (T-01-10). Required
    # against the twelve-file scaffold body specifically -- the pointer
    # (read further down, after these are written) resolves independently
    # against its own single file, so one incomplete variant never forces
    # the other artifact into the wrong language.
    templates_root = Path(__file__).resolve().parent.parent / "templates"
    templates_dir, report_variant, fallback_note = resolve_template_dir(
        templates_root, args.language, args.template_variant, tuple(TEMPLATE_MAP.keys())
    )
    if templates_dir is None:
        print(
            "error: unknown --template-variant {!r}: {} does not exist".format(
                args.template_variant, templates_root / args.template_variant
            ),
            file=sys.stderr,
        )
        return 1

    if fallback_note:
        print("templates: {} ({})".format(report_variant, fallback_note))
    else:
        print("templates: {}".format(report_variant))

    results = []

    for folder in FOLDERS:
        folder_path = os.path.join(target_root, folder)
        if not under_root(target_root, folder_path):
            print("error: refusing to create {} outside the target root".format(folder_path), file=sys.stderr)
            return 1
        os.makedirs(folder_path, exist_ok=True)

    for leaf in GITKEEP_LEAVES:
        gitkeep_path = os.path.join(target_root, leaf, ".gitkeep")
        if not under_root(target_root, gitkeep_path):
            print("error: refusing to write {} outside the target root".format(gitkeep_path), file=sys.stderr)
            return 1
        status = write_if_missing(gitkeep_path, "")
        results.append((status, os.path.relpath(gitkeep_path, target_root)))

    counterparts = [parse_counterpart(spec) for spec in args.counterpart]
    cfg = {
        "language": args.language,
        "counterparts": counterparts,
        "confidential_names": args.confidential_names,
        "consent_recorded": args.consent_recorded == "true",
        "consent_source": args.consent_source,
        "timestamps": args.timestamps,
        "date_format": args.date_format,
        "status_header": args.status_header,
        "staleness_days": args.staleness_days,
    }

    dossier_yaml_path = os.path.join(target_root, "dossier.yaml")
    if not under_root(target_root, dossier_yaml_path):
        print("error: refusing to write {} outside the target root".format(dossier_yaml_path), file=sys.stderr)
        return 1
    status = write_if_missing(dossier_yaml_path, render_dossier_yaml(cfg))
    results.append((status, "dossier.yaml"))

    today = datetime.date.today().isoformat()

    for template_name, target_rel in TEMPLATE_MAP.items():
        template_path = templates_dir / template_name
        target_path = os.path.join(target_root, target_rel)
        if not under_root(target_root, target_path):
            print("error: refusing to write {} outside the target root".format(target_path), file=sys.stderr)
            return 1
        with open(template_path, "r", encoding="utf-8") as handle:
            raw_text = handle.read()
        rendered_text = render_template(raw_text, today)
        status = write_if_missing(target_path, rendered_text)
        results.append((status, os.path.relpath(target_path, target_root)))

    for status, relative_path in results:
        print("{}: {}".format(status, relative_path))

    # Protocol pointer (SCAF-05, D-16): AGENTS.md always, CLAUDE.md only
    # when it already exists, both marker-delimited via
    # upsert_marker_section() so a re-run updates the section in place
    # rather than duplicating it. Resolved against its own single required
    # file -- see the comment on the call above.
    pointer_dir, _pointer_variant, _pointer_fallback_note = resolve_template_dir(
        templates_root, args.language, args.template_variant, ("AGENTS-pointer.md",)
    )
    if pointer_dir is None:
        print(
            "error: unknown --template-variant {!r}: {} is missing AGENTS-pointer.md".format(
                args.template_variant, templates_root / args.template_variant
            ),
            file=sys.stderr,
        )
        return 1

    with open(pointer_dir / "AGENTS-pointer.md", "r", encoding="utf-8") as handle:
        pointer_body = render_template(handle.read(), today)

    agents_md_path = os.path.join(target_root, "AGENTS.md")
    if not under_root(target_root, agents_md_path):
        print("error: refusing to write {} outside the target root".format(agents_md_path), file=sys.stderr)
        return 1
    try:
        agents_result = upsert_marker_section(agents_md_path, pointer_body)
    except MarkerSectionError as exc:
        print("error: {}".format(exc), file=sys.stderr)
        return 1
    print("pointer: {} AGENTS.md".format(agents_result))

    claude_md_path = os.path.join(target_root, "CLAUDE.md")
    if not under_root(target_root, claude_md_path):
        print("error: refusing to write {} outside the target root".format(claude_md_path), file=sys.stderr)
        return 1
    if os.path.exists(claude_md_path):
        try:
            claude_result = upsert_marker_section(claude_md_path, pointer_body)
        except MarkerSectionError as exc:
            print("error: {}".format(exc), file=sys.stderr)
            return 1
        print("pointer: {} CLAUDE.md".format(claude_result))
    else:
        print("pointer: skipped CLAUDE.md (absent)")

    created_count = sum(1 for status, _ in results if status == "created")
    kept_count = sum(1 for status, _ in results if status == "kept")
    print("done: {} created, {} kept".format(created_count, kept_count))

    return 0


if __name__ == "__main__":
    sys.exit(main())
