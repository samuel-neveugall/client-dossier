#!/usr/bin/env python3
# vibeflow:allow-large-file -- mechanics-tier linter kept as ONE file on
# purpose (Q-6): a bare-skills install copies scripts/ wholesale and runs this
# file by path, so a second importable module would turn sys.path into a
# distribution concern (DIST-03). Splitting is a Phase 7 conversation.
# Tracked in 02-01-SUMMARY.md and .planning/WINDOWS.md.
"""Lint a client-dossier repository.

Mechanics tier only (spec principle: "skills carry the judgement, scripts
carry the mechanics"). From PATH the linter walks upward to the nearest
dossier.yaml, reads it through a quotedness-preserving YAML-subset parser
(or the json module when the file starts with `{`, D-25), walks the dossier
once and prints one finding per line in the compiler shape

    <relative/path>:<line>: ERROR [E7] <message>

followed by the `N error(s), M warning(s)` summary, always last (D-04).

It is read-only: it never writes, fixes, reformats, renames or deletes
anything, never prompts, and never spawns a process. Exit codes (D-02, P-08):
0 no error (warnings allowed), 1 at least one error, 2 no dossier.yaml found
upward or dossier.yaml unreadable, 3 internal error.

Python 3 standard library only, targeting Python >= 3.8.
"""

import argparse
import datetime
import json
import os
import re
import sys
import unicodedata
from pathlib import Path

# ---------------------------------------------------------------------------
# PROTOCOL KEYWORDS
#
# English in every dossier, whatever `language:` says (spec Sec3.2,
# CLAUDE.md). The linter greps these literals. A per-language label table is
# forbidden: never add one, and never derive these from dossier.yaml.
# ---------------------------------------------------------------------------

# The six status-header field names an outbound file opens with (spec Sec3.2,
# D-07). Checked by check_outbound_headers (plan 02-02).
PROTOCOL_FIELDS = ("Status", "To", "Subject", "Deadline", "Written by", "Rules")

# The three status values (spec Sec3.2, D-08). `reviewed by` takes a name,
# `sent` takes an absolute date and a sender.
STATUS_VALUES = ("draft", "reviewed by", "sent")

# The label every living file carries (D-13), grepped in English even in a
# French dossier (ROADMAP criterion 3).
LAST_UPDATED_LABEL = "Last updated:"

# ---------------------------------------------------------------------------
# LAYOUT CONSTANTS -- fixed English names, never configurable (spec Sec3.2).
# ---------------------------------------------------------------------------

# The root marker, and the only one (D-25): a JSON config keeps this name.
CONFIG_NAME = "dossier.yaml"

# The seven living files (D-13). Iterated explicitly, never globbed:
# dossier/README.md is not a living file, and a glob over dossier/ is what
# makes a clean scaffold raise spurious findings (P-02).
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

# The three outbound subfolders whose files carry dated names (D-10).
OUTBOUND_DIR = "outbound"
OUTBOUND_SUBS = ("deliverables", "mails", "calls")

# Exempt from the outbound checks E1-E4 (D-06). This exemption is what keeps
# a freshly scaffolded dossier clean: outbound/README.md quotes the status
# header verbatim, placeholders included (P-01). `.gitkeep` is additionally
# dropped from the walk everywhere (LINT-01); README.md stays visible to E5
# (Q-5: a leaked name is a leak wherever it sits).
EXEMPT_BASENAMES = frozenset((".gitkeep", "README.md"))
GITKEEP = ".gitkeep"

# Never descended into (D-03's other half: sub-dossiers are pruned too).
PRUNED_DIRS = frozenset((".git",))

# Files larger than this are skipped, never read (T-02-04).
MAX_READ_BYTES = 5000000

# The status header must sit within the first N lines (D-07).
STATUS_HEADER_WINDOW = 10

# Schema defaults (spec Sec3.2, D-24.2, Q-3).
SUPPORTED_VERSION = 1
DEFAULT_STALENESS_DAYS = 7

# The YAML 1.2 Core Schema boolean spellings -- the only ones accepted for
# consent_recorded, and only unquoted (D-24.2). yes/no/on/off/1/0 are errors.
TRUE_SCALARS = frozenset(("true", "True", "TRUE"))
FALSE_SCALARS = frozenset(("false", "False", "FALSE"))

# LANGUAGE_WORDS lands here in plan 02-05: language DATA (relative-date words,
# opinion markers), not a protocol-keyword table (D-19).

# Severities and exit codes (D-02, D-04, P-08).
ERROR = "ERROR"
WARNING = "WARNING"
EXIT_CLEAN = 0
EXIT_ERRORS = 1
EXIT_NO_DOSSIER = 2
EXIT_INTERNAL = 3

_KEY_RE = re.compile(r"([A-Za-z_][A-Za-z0-9_-]*):(?:[ \t]+(.*))?")
_INT_RE = re.compile(r"[-+]?[0-9]+")
_LAST_UPDATED_RE = re.compile(r"^[ \t]*Last updated:[ \t]*(.*)$")
_DATE_PREFIX_RE = re.compile(r"([0-9]{4})-([0-9]{2})-([0-9]{2})(?![0-9])")

# A quote only opens a quoted scalar at the start of a token, so the
# apostrophe in a plain `role: it's fine` does not swallow a trailing comment.
_QUOTE_OPENERS = " \t[,"

# Characters a YAML plain scalar may not start with; the subset has no
# anchors, aliases, tags, block scalars or directives (D-22).
_PLAIN_FORBIDDEN_START = "|>&*!%@`{}]"

_DOUBLE_ESCAPES = {"\\": "\\", '"': '"', "/": "/", "n": "\n", "t": "\t", "r": "\r", "0": "\0"}


class Finding:
    """One report row: `<path>:<line>: <severity> [<ident>] <message>`."""

    __slots__ = ("path", "line", "severity", "ident", "message")

    def __init__(self, path, line, severity, ident, message):
        self.path = path
        self.line = line
        self.severity = severity
        self.ident = ident
        self.message = message


# ---------------------------------------------------------------------------
# PARSER -- raw strings plus structure, no implicit typing (D-24.1).
# ---------------------------------------------------------------------------


class Scalar:
    """One dossier.yaml scalar, with the two facts the schema needs.

    `quoted` is what makes D-24's consent_recorded rule expressible: the
    parser unquotes (D-24.1) but must not forget that it did, or
    `consent_recorded: "true"` becomes indistinguishable from
    `consent_recorded: true` -- the silent coercion D-24 forbids (F-01).
    """

    __slots__ = ("text", "quoted", "line")

    def __init__(self, text, quoted, line):
        self.text = text
        self.quoted = quoted
        self.line = line


class Seq(list):
    """A parsed sequence that remembers the line its key sat on."""

    __slots__ = ("line",)

    def __init__(self, items=(), line=0):
        list.__init__(self, items)
        self.line = line


class Map(dict):
    """A parsed mapping that remembers the line its key sat on."""

    __slots__ = ("line",)

    def __init__(self, items=(), line=0):
        dict.__init__(self, items)
        self.line = line


def strip_comment(line):
    """Remove an end-of-line `#` comment, respecting quoted scalars.

    spec Sec3.2 shows end-of-line comments on real dossier.yaml lines, and
    consent_source legitimately contains a `#`. A `#` only opens a comment
    when it is outside a quoted scalar AND at the start of the line or after
    whitespace. Backslash escapes are honoured inside double quotes.
    """
    out = []
    quote = None
    escaped = False
    for i, ch in enumerate(line):
        if quote:
            out.append(ch)
            if escaped:
                escaped = False
            elif quote == '"' and ch == "\\":
                escaped = True
            elif ch == quote:
                quote = None
            continue
        if ch in "\"'" and (i == 0 or line[i - 1] in _QUOTE_OPENERS):
            quote = ch
        elif ch == "#" and (i == 0 or line[i - 1] in " \t"):
            break
        out.append(ch)
    return "".join(out).rstrip()


def _unquote_double(text):
    """The body of a double-quoted scalar, escapes resolved."""
    inner = text[1:-1]
    out = []
    i = 0
    while i < len(inner):
        ch = inner[i]
        if ch == "\\":
            if i + 1 >= len(inner) or inner[i + 1] not in _DOUBLE_ESCAPES:
                raise ValueError("unsupported escape in a double-quoted scalar")
            out.append(_DOUBLE_ESCAPES[inner[i + 1]])
            i += 2
            continue
        if ch == '"':
            raise ValueError("unescaped double quote inside a double-quoted scalar")
        out.append(ch)
        i += 1
    return "".join(out)


def _unquote_single(text):
    """The body of a single-quoted scalar; `''` is the only escape."""
    inner = text[1:-1]
    if "'" in inner.replace("''", ""):
        raise ValueError("unescaped single quote inside a single-quoted scalar")
    return inner.replace("''", "'")


def parse_scalar(text, line):
    """One scalar token -> Scalar. Raises ValueError outside the subset."""
    if text[:1] == '"':
        if len(text) < 2 or text[-1] != '"':
            raise ValueError("unterminated double-quoted scalar")
        return Scalar(_unquote_double(text), True, line)
    if text[:1] == "'":
        if len(text) < 2 or text[-1] != "'":
            raise ValueError("unterminated single-quoted scalar")
        return Scalar(_unquote_single(text), True, line)
    if text[:1] == "[" or (text and text[0] in _PLAIN_FORBIDDEN_START):
        raise ValueError("construct outside the supported YAML subset")
    return Scalar(text, False, line)


def _split_flow(inner):
    """Split the inside of `[ a, "b, c" ]` on the commas outside quotes."""
    items = []
    buf = []
    quote = None
    escaped = False
    for i, ch in enumerate(inner):
        if quote:
            buf.append(ch)
            if escaped:
                escaped = False
            elif quote == '"' and ch == "\\":
                escaped = True
            elif ch == quote:
                quote = None
            continue
        if ch in "\"'" and (i == 0 or inner[i - 1] in _QUOTE_OPENERS):
            quote = ch
        elif ch == ",":
            items.append("".join(buf).strip())
            buf = []
            continue
        elif ch in "[]{}":
            raise ValueError("nested flow collection outside the supported YAML subset")
        buf.append(ch)
    if quote:
        raise ValueError("unterminated quote in a flow sequence")
    items.append("".join(buf).strip())
    if items and items[-1] == "":
        items.pop()  # a trailing comma, or `[]`
    if any(item == "" for item in items):
        raise ValueError("empty item in a flow sequence")
    return items


def parse_value(text, line):
    """A value after `key: ` -> Scalar or Seq. Raises ValueError outside the subset."""
    if text[:1] == "[":
        if text[-1] != "]":
            raise ValueError("unterminated flow sequence")
        return Seq((parse_scalar(item, line) for item in _split_flow(text[1:-1])), line)
    return parse_scalar(text, line)


def _value_or_empty(text, line):
    """`key:` with nothing after it is an empty unquoted scalar (YAML null)."""
    if text is None or text.strip() == "":
        return Scalar("", False, line)
    return parse_value(text.strip(), line)


def parse_yaml_subset(text, skipped=None):
    """Parse the dossier.yaml subset into Scalar / Seq / Map values.

    Supported (D-22, D-24.1): `key: value`, flow sequences `[ a, b ]`, block
    sequences `- item`, block sequences of mappings (`counterparts`), a
    one-level nested mapping, `#` comments (quote-aware), single and double
    quotes. No implicit int/bool/null/float/date conversion happens here:
    every scalar comes back as its raw text plus a `quoted` flag, and
    apply_schema() alone decides a field's type. A line outside the subset
    is skipped and its number appended to `skipped` -- never a crash.
    """
    data = {}
    block_key = None
    block_indent = -1
    item = None
    item_indent = -1
    for number, raw in enumerate(text.splitlines(), 1):
        line = strip_comment(raw)
        body = line.strip()
        if not body or body in ("---", "..."):
            continue
        indent = len(line) - len(line.lstrip(" \t"))
        try:
            if indent == 0:
                block_key, block_indent, item = None, -1, None
                match = _KEY_RE.fullmatch(body)
                if match is None:
                    raise ValueError("not a `key: value` line")
                key, value = match.group(1), match.group(2)
                if value is None or value.strip() == "":
                    data[key] = Scalar("", False, number)
                    block_key = key
                else:
                    data[key] = parse_value(value.strip(), number)
                continue
            if block_key is None:
                raise ValueError("indented line outside a block")
            current = data[block_key]
            if body == "-" or body.startswith("- "):
                if isinstance(current, Scalar):
                    current = data[block_key] = Seq((), current.line)
                    block_indent = indent
                if not isinstance(current, Seq) or indent != block_indent:
                    raise ValueError("sequence item at an unsupported position")
                entry = body[1:].strip()
                match = _KEY_RE.fullmatch(entry) if entry else None
                if match is not None:
                    item = Map((), number)
                    item[match.group(1)] = _value_or_empty(match.group(2), number)
                    current.append(item)
                    item_indent = indent + 1 + (len(body[1:]) - len(body[1:].lstrip()))
                else:
                    item = None
                    current.append(_value_or_empty(entry, number))
                continue
            match = _KEY_RE.fullmatch(body)
            if match is None:
                raise ValueError("not a `key: value` line")
            if item is not None and indent == item_indent:
                item[match.group(1)] = _value_or_empty(match.group(2), number)
                continue
            if isinstance(current, Scalar):
                current = data[block_key] = Map((), current.line)
                block_indent = indent
            if isinstance(current, Map) and indent == block_indent:
                current[match.group(1)] = _value_or_empty(match.group(2), number)
                continue
            raise ValueError("mapping line at an unsupported indentation")
        except ValueError:
            if skipped is not None:
                skipped.append(number)
    return data


def json_to_scalars(obj):
    """Map json.loads output onto the same Scalar / Seq / Map shape (D-25).

    JSON has real booleans and numbers where the YAML branch has raw text,
    and no line numbers at all: every value carries line 0, so a finding
    against a JSON config is reported at `dossier.yaml:0`. JSON strings are
    marked quoted, so `"consent_recorded": "true"` is rejected for the same
    reason the YAML spelling is. `bool` is tested before `int` because it
    subclasses `int` in Python.
    """

    def convert(value):
        if isinstance(value, bool):
            return Scalar("true" if value else "false", False, 0)
        if isinstance(value, int):
            return Scalar(str(value), False, 0)
        if isinstance(value, float):
            return Scalar(repr(value), False, 0)
        if value is None:
            return Scalar("", False, 0)
        if isinstance(value, str):
            return Scalar(value, True, 0)
        if isinstance(value, list):
            return Seq((convert(entry) for entry in value), 0)
        if isinstance(value, dict):
            return Map(((key, convert(entry)) for key, entry in value.items()), 0)
        return Scalar(str(value), True, 0)

    return {key: convert(value) for key, value in obj.items()}


# ---------------------------------------------------------------------------
# SCHEMA -- the single place a dossier.yaml field acquires a type (D-24.2).
# ---------------------------------------------------------------------------


def _line_of(value):
    return getattr(value, "line", 0)


def _config_error(findings, value, message):
    findings.append(Finding(CONFIG_NAME, _line_of(value), ERROR, "C1", message))


def as_str(value, field, findings, default=""):
    """D-24.2: str verbatim, whatever the spelling -- `no` stays "no" (D-23)."""
    if value is None:
        return default
    if not isinstance(value, Scalar):
        _config_error(findings, value, "{} must be a single string value".format(field))
        return default
    return value.text


def as_bool(value, field, findings):
    """D-24.2: only an UNQUOTED YAML 1.2 Core Schema boolean. Never coerce.

    Kept apart from as_int() on purpose (P-15): the integer regex accepts
    `1`/`0`, and those must never reach the boolean path.
    """
    if value is None:
        return False
    if (not isinstance(value, Scalar) or value.quoted
            or value.text not in TRUE_SCALARS | FALSE_SCALARS):
        _config_error(findings, value, "{} must be an unquoted boolean: true or false".format(field))
        # Fail closed -- the single most security-relevant line in this file:
        # consent_recorded gates the confidential-name leak check, so a
        # malformed flag reads as False and the check stays armed (T-02-02).
        return False
    return value.text in TRUE_SCALARS


def as_int(value, field, findings, default, minimum=None):
    """D-24.2: an integer via `[-+]?[0-9]+` on the raw text.

    `.quoted` is deliberately ignored here (Q-2): unlike consent_recorded,
    an integer field gates no safety control, so `staleness_days: "7"` is 7.
    Do not "fix" this asymmetry with as_bool().
    """
    if value is None:
        return default
    if not isinstance(value, Scalar) or _INT_RE.fullmatch(value.text.strip()) is None:
        _config_error(findings, value, "{} must be an integer".format(field))
        return default
    number = int(value.text.strip())
    if minimum is not None and number < minimum:
        _config_error(findings, value, "{} must be an integer of at least {}".format(field, minimum))
        return default
    return number


def _as_str_list(value, field, findings):
    """A sequence of strings; an absent or empty value is the empty list."""
    if value is None or (isinstance(value, Scalar) and not value.quoted and value.text == ""):
        return []
    if isinstance(value, Scalar):
        # Fail closed: keep the lone value rather than drop what may be a name.
        _config_error(findings, value, "{} must be a list".format(field))
        return [value.text]
    if not isinstance(value, list):
        _config_error(findings, value, "{} must be a list".format(field))
        return []
    out = []
    for entry in value:
        if not isinstance(entry, Scalar):
            _config_error(findings, value, "{} must be a list of strings".format(field))
            continue
        out.append(entry.text)
    return out


def _schema_counterparts(value, findings):
    """counterparts[].name|role -> str, counterparts[].contacts[] -> [str]."""
    if value is None or (isinstance(value, Scalar) and not value.quoted and value.text == ""):
        return []
    if not isinstance(value, list):
        _config_error(findings, value, "counterparts must be a list of name/role/contacts entries")
        return []
    out = []
    for entry in value:
        if not isinstance(entry, dict):
            _config_error(findings, entry, "counterparts must be a list of name/role/contacts entries")
            continue
        out.append({
            "name": as_str(entry.get("name"), "counterparts[].name", findings),
            "role": as_str(entry.get("role"), "counterparts[].role", findings),
            "contacts": _as_str_list(entry.get("contacts"), "counterparts[].contacts", findings),
        })
    return out


def apply_schema(raw, findings):
    """Type every field the linter reads; emit C1 on a malformed one.

    The per-field typing authority (D-24.2). Unknown keys are ignored (D-22).
    Every reader returns a safe default after reporting, so one malformed
    field never hides the findings of the rest of the dossier.
    """
    config = {}
    version = raw.get("version")
    config["version"] = SUPPORTED_VERSION
    if version is not None:
        if (not isinstance(version, Scalar) or _INT_RE.fullmatch(version.text.strip()) is None
                or int(version.text.strip()) != SUPPORTED_VERSION):
            _config_error(findings, version, "version must be {} (the only dossier.yaml version this linter reads)".format(
                SUPPORTED_VERSION))
    for field in ("language", "consent_source", "timestamps", "date_format", "status_header"):
        config[field] = as_str(raw.get(field), field, findings)
    config["counterparts"] = _schema_counterparts(raw.get("counterparts"), findings)
    names = _as_str_list(raw.get("confidential_names"), "confidential_names", findings)
    config["confidential_names"] = [name for name in names if name.strip()]
    config["consent_recorded"] = as_bool(raw.get("consent_recorded"), "consent_recorded", findings)
    config["staleness_days"] = as_int(raw.get("staleness_days"), "staleness_days", findings,
                                      DEFAULT_STALENESS_DAYS, minimum=1)
    # Where E6 points: the source line when present, else the flag's line.
    source = raw.get("consent_source")
    config["consent_line"] = _line_of(source if source is not None else raw.get("consent_recorded"))
    return config


def consent_is_recorded(config):
    """True only when the flag is true AND a source is filled in (spec Sec3.2).

    The one condition under which the confidential-name check (E5, plan
    02-02) is suppressed.
    """
    return config["consent_recorded"] and config["consent_source"].strip() != ""


def load_config(path, findings):
    """Read dossier.yaml, pick the branch (D-25), apply the schema.

    Returns the typed config, or None when the file cannot be read at all
    (the caller turns that into exit 2, D-22). A JSON config that does not
    parse is a C1 error, not an unreadable file: the dossier is there and
    its configuration is broken.
    """
    text = read_text_safe(path, follow_symlink=True)
    if text is None:
        return None
    if text.lstrip()[:1] == "{":
        try:
            obj = json.loads(text)
        except ValueError as exc:
            findings.append(Finding(CONFIG_NAME, getattr(exc, "lineno", 0), ERROR, "C1",
                                    "dossier.yaml starts with `{` but is not valid JSON"))
            obj = {}
        if not isinstance(obj, dict):
            findings.append(Finding(CONFIG_NAME, 0, ERROR, "C1", "dossier.yaml JSON must be an object"))
            obj = {}
        raw = json_to_scalars(obj)
    else:
        skipped = []
        raw = parse_yaml_subset(text, skipped)
        for number in skipped:
            findings.append(Finding(CONFIG_NAME, number, WARNING, "C0",
                                    "line {} skipped: outside the supported YAML subset".format(number)))
    return apply_schema(raw, findings)


# ---------------------------------------------------------------------------
# ROOT DISCOVERY AND THE WALK
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


class Tree:
    """The result of the single walk: POSIX paths relative to the root."""

    __slots__ = ("files", "dirs", "file_set")

    def __init__(self, files, dirs):
        self.files = files
        self.dirs = dirs
        self.file_set = frozenset(files)


def walk_tree(root):
    """One pruned, sorted, read-only os.walk pass over the dossier (D-03).

    Pruning is a slice-assignment of `dirnames[:]` while still in the parent
    (the documented os.walk idiom): `.git` is dropped, and so is every child
    directory that itself holds a dossier.yaml -- a nested dossier is a
    boundary, never descended into and never merged into this one's findings.
    Directory symlinks are listed but never followed (the os.walk default,
    deliberately not overridden -- T-02-03). `.gitkeep` is dropped
    everywhere (LINT-01).
    """
    files = []
    dirs = []
    for dirpath, dirnames, filenames in os.walk(root, topdown=True):
        dirnames.sort()
        filenames.sort()
        dirnames[:] = [
            name for name in dirnames
            if name not in PRUNED_DIRS
            and not os.path.isfile(os.path.join(dirpath, name, CONFIG_NAME))
        ]
        rel_dir = os.path.relpath(dirpath, root)
        prefix = "" if rel_dir == os.curdir else rel_dir.replace(os.sep, "/") + "/"
        for name in dirnames:
            dirs.append(prefix + name)
        for name in filenames:
            if name != GITKEEP:
                files.append(prefix + name)
    return Tree(files, dirs)


def read_text_safe(path, follow_symlink=False):
    """The decoded UTF-8 text of `path`, or None -- never an exception.

    Guards (P-07, T-02-03, T-02-04): a symlinked file is skipped before it is
    opened, anything but a regular file (a FIFO would block) is skipped, a
    file over MAX_READ_BYTES is skipped, and a decode or OS error returns
    None instead of aborting the run. Opens read-only, always.
    """
    try:
        if not follow_symlink and os.path.islink(path):
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


def normalise(text):
    """NFC plus typographic-apostrophe folding (P-05).

    macOS editors may store accented text decomposed (NFD); a smart-quotes
    editor writes U+2019 where the word lists use an ASCII apostrophe.
    """
    return unicodedata.normalize("NFC", text).replace("\u2019", "'")


def sanitise_path(rel):
    """Escape every control character in a printed line (T-02-01).

    A filename may legally contain a newline; printed raw, a crafted name
    forges a summary line a later consumer would believe. Escaped as \\xNN:
    C0 controls, DEL, C1 controls, and the surrogate-escaped bytes os.walk
    returns for a name that is not valid UTF-8 (which would otherwise crash
    the print). U+2028/U+2029 are escaped as \\uNNNN because Python's
    str.splitlines() treats them as line breaks. Applied at exactly one call
    site, the reporter, to the whole finding line.
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


# ---------------------------------------------------------------------------
# CHECKS -- in identifier order. Each takes (root, tree, config, findings).
# E1-E5, E8, E9, W1 and W2 land in plans 02-02, 02-04 and 02-05.
# ---------------------------------------------------------------------------


def check_consent_source(root, tree, config, findings):
    """E6: consent_recorded true with an empty or absent consent_source (D-12)."""
    if config["consent_recorded"] and config["consent_source"].strip() == "":
        findings.append(Finding(CONFIG_NAME, config["consent_line"], ERROR, "E6",
                                "consent_recorded: true with an empty consent_source "
                                "(a consent without a source is an opinion)"))


def check_living_files(root, tree, config, findings):
    """E7: each living file exists and carries `Last updated: YYYY-MM-DD` (D-13).

    Iterates the explicit LIVING_FILES tuple, never a glob (P-02). The first
    `Last updated:` line wins; its value must start with a real calendar date.
    """
    for name in LIVING_FILES:
        rel = LIVING_DIR + "/" + name
        if rel not in tree.file_set:
            findings.append(Finding(rel, 0, ERROR, "E7", "living file is missing"))
            continue
        text = read_text_safe(os.path.join(root, LIVING_DIR, name))
        if text is None:
            findings.append(Finding(rel, 0, ERROR, "E7",
                                    "living file cannot be read (symlink, over 5 MB, or not UTF-8)"))
            continue
        for number, line in enumerate(text.splitlines(), 1):
            match = _LAST_UPDATED_RE.match(line)
            if match is None:
                continue
            date = _DATE_PREFIX_RE.match(match.group(1))
            if date is None or not _is_real_date(*date.groups()):
                findings.append(Finding(rel, number, ERROR, "E7",
                                        "{} does not carry an absolute YYYY-MM-DD date".format(
                                            LAST_UPDATED_LABEL)))
            break
        else:
            findings.append(Finding(rel, 0, ERROR, "E7", "no {} line".format(LAST_UPDATED_LABEL)))


CHECKS = (
    check_consent_source,
    check_living_files,
)


# ---------------------------------------------------------------------------
# REPORTER
# ---------------------------------------------------------------------------


def report(findings, infos=()):
    """Print informational lines, the sorted findings, then the summary (D-04).

    Sorted by (path, line, identifier) -- message as the last tie-breaker --
    so two runs over one tree are byte-identical. Every line goes through
    sanitise_path() here and only here. Returns (errors, warnings).
    """
    lines = ["info: {}".format(info) for info in infos]
    for finding in sorted(findings, key=lambda f: (f.path, f.line, f.ident, f.message)):
        lines.append("{}:{}: {} [{}] {}".format(
            finding.path, finding.line, finding.severity, finding.ident, finding.message))
    for line in lines:
        print(sanitise_path(line))
    errors = sum(1 for finding in findings if finding.severity == ERROR)
    warnings = sum(1 for finding in findings if finding.severity == WARNING)
    print("{} error(s), {} warning(s)".format(errors, warnings))
    return errors, warnings


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def build_parser():
    parser = argparse.ArgumentParser(
        description="Lint a client-dossier repository (mechanics tier; read-only, never fixes anything).",
        epilog=(
            "The dossier root is the nearest folder holding dossier.yaml, found by walking "
            "upward from PATH with no stop condition, so a dossier nested in a larger "
            "repository is found. A subfolder holding its own dossier.yaml is a separate "
            "dossier and is skipped. Exit codes: 0 no error (warnings allowed), 1 at least one "
            "error, 2 no dossier.yaml found upward or dossier.yaml unreadable (argparse usage "
            "errors also exit 2), 3 internal error."
        ),
    )
    parser.add_argument(
        "path",
        nargs="?",
        default=".",
        help="A path inside the dossier (default: the current directory); the linter walks "
        "upward from it to the nearest dossier.yaml.",
    )
    return parser


def _run(start):
    if not os.path.exists(start):
        print("error: no such file or directory: {}".format(start), file=sys.stderr)
        return EXIT_NO_DOSSIER
    root = find_root(start)
    if root is None:
        print("error: no dossier.yaml found from {} upward".format(os.path.realpath(start)), file=sys.stderr)
        return EXIT_NO_DOSSIER
    findings = []
    config = load_config(os.path.join(root, CONFIG_NAME), findings)
    if config is None:
        print("error: cannot read {} (not a regular UTF-8 file under 5 MB)".format(
            os.path.join(root, CONFIG_NAME)), file=sys.stderr)
        return EXIT_NO_DOSSIER
    tree = walk_tree(root)
    for check in CHECKS:
        check(root, tree, config, findings)
    errors, _warnings = report(findings)
    return EXIT_ERRORS if errors else EXIT_CLEAN


def main(argv=None):
    args = build_parser().parse_args(argv)
    try:
        return _run(args.path)
    except Exception as exc:  # P-08: never masquerade as "this dossier has errors"
        print("error: internal linter failure: {}: {}".format(type(exc).__name__, exc), file=sys.stderr)
        return EXIT_INTERNAL


if __name__ == "__main__":
    sys.exit(main())
