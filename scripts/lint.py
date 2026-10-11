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
import bisect
import datetime
import difflib
import html
import json
import os
import re
import sys
import unicodedata
import urllib.parse
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

# Exempt from the outbound checks E1-E3 (D-06). This exemption is what keeps
# a freshly scaffolded dossier clean: outbound/README.md quotes the status
# header verbatim, placeholders included (P-01). A PATH, never a basename: a
# README.md saved in outbound/mails/ or deliverables/ is an outbound file
# like any other (WR-04). `.gitkeep` is dropped from the walk everywhere
# (LINT-01); the README stays visible to E5 (Q-5: a leaked name is a leak
# wherever it sits).
EXEMPT_PATHS = frozenset((OUTBOUND_DIR + "/README.md",))

# E4 alone keeps D-10's own exemption: a README.md directly under
# outbound/{deliverables,mails,calls}/ need not carry a dated name. It still
# needs its status header (E1-E3 above), so a draft saved under that name
# cannot bypass the header protocol.
README_NAME = "README.md"

# Metadata the operating system drops into any folder it displays: Finder's
# .DS_Store, Explorer's Thumbs.db and desktop.ini (WR-05). Not outbound
# documents, so exempt from E1-E4; still walked, so E5 still reads them.
OS_METADATA_NAMES = frozenset((".DS_Store", "Thumbs.db", "desktop.ini"))
GITKEEP = ".gitkeep"

# Rendered binaries carry no text header, so they are outside E1-E3 (D-07,
# A-06). Compared lowercased. An unlisted binary is not a crash either: it
# reaches read_text_safe(), fails to decode and is reported as unreadable.
# E5 is not extension-scoped: a binary's filename is still searched (P-07).
BINARY_EXTS = frozenset((
    ".pdf", ".docx",
    ".png", ".jpg", ".jpeg", ".gif", ".webp",
    ".odt", ".pptx", ".xlsx",
))

# Never descended into (D-03's other half: sub-dossiers are pruned too). A
# name in here is silently pruned only outside the fixed layout; inside it,
# walk_tree still never descends into it but records its path instead of
# dropping it, so it can be reported rather than pruned in silence
# (D-GAP-3, G-02-4e).
PRUNED_DIRS = frozenset((".git",))

# The fixed-layout folders (spec Sec3.2). No sub-dossier can legitimately
# live in one of them or below, so a dossier.yaml there is never a D-03
# boundary: pruning on it would hide the folder from every check (WR-03). A
# folder spelt as a case variant of one of these names, or of an
# OUTBOUND_SUBS name directly under outbound/, is ERROR [E1] at the folder
# (D-GAP-2, CR-01, G-02-4a): on a case-insensitive filesystem it is the same
# folder the agent writes to, and its files would otherwise meet no check
# at all.
LAYOUT_DIRS = frozenset(("sources", LIVING_DIR, "outbound", "knowledge"))
_LAYOUT_DIRS_FOLDED = frozenset(d.casefold() for d in LAYOUT_DIRS)

# The agent folder (D-14, spec Sec4.4 check 7). Allowed at exactly
# `<root>/.claude` and nowhere below it: a second one under the dossier means
# an agent configuration that the root's own does not govern.
AGENT_DIR = ".claude"

# Rendered deliverables that need their source beside them (D-15, spec Sec4.4
# check 8): a PDF or a Word file cannot be diffed or corrected in place, so
# the text it was rendered from must sit next to it under the same stem.
# Compared lowercased.
RENDERED_EXTS = frozenset((".pdf", ".docx"))

# What counts as that source (D-15, spec Sec4.4 check 8). Compared lowercased.
RENDER_SOURCE_EXTS = frozenset((".md", ".html"))

# Files larger than this are skipped, never read (T-02-04).
MAX_READ_BYTES = 5000000

# The status header must sit within the first N lines (D-07).
STATUS_HEADER_WINDOW = 10

# The fields a status header must carry to be complete (A-02). Subject: is
# required under outbound/mails/ only; Deadline: and Rules: stay optional, so
# the linter cannot become the reason a legitimate draft is rejected.
REQUIRED_FIELDS = ("Status", "To", "Written by")
MAIL_REQUIRED_FIELDS = REQUIRED_FIELDS + ("Subject",)

# Schema defaults (spec Sec3.2, D-24.2, Q-3).
SUPPORTED_VERSION = 1
DEFAULT_STALENESS_DAYS = 7

# The YAML 1.2 Core Schema boolean spellings -- the only ones accepted for
# consent_recorded, and only unquoted (D-24.2). yes/no/on/off/1/0 are errors.
TRUE_SCALARS = frozenset(("true", "True", "TRUE"))
FALSE_SCALARS = frozenset(("false", "False", "FALSE"))

# The YAML 1.2 Core Schema null spellings. consent_source is still read as a
# verbatim string (D-24.2), but for the consent gate alone an UNQUOTED null
# means "no value" -- the "true without a source" of spec Sec3.2 (WR-02).
NULL_SCALARS = frozenset(("null", "Null", "NULL", "~"))

# ===========================================================================
# LANGUAGE DATA -- the only place this file knows the dossier's language.
#
# These are word lists for the two prose heuristics, W1 and W2 (D-19, D-21,
# spec Sec4.4): language DATA, not a protocol-keyword table. A per-language
# table of labels is forbidden, because the protocol keywords above are
# English in every dossier and a regex has to find them without reading a
# mapping -- so never add `Last updated:` or a status field here.
#
# Selected by `language:` from dossier.yaml; a language with no entry skips
# W1 and W2 with one informational line (D-20). Apostrophes are written
# ASCII: normalise() folds the typographic one on the text side (P-05).
# Every entry is matched with boundary_pattern(), never as a substring
# (P-04: `hier` is inside `fichier`). Extendable without a contract change.
# ===========================================================================

LANGUAGE_WORDS = {
    "en": {
        "relative_dates": (
            "tomorrow", "yesterday", "today", "next week", "last week", "this week",
            "next month", "last month", "soon", "recently", "in a few days",
        ),
        "opinion_markers": (
            "reconstructed", "I think", "probably", "it seems", "apparently", "maybe",
        ),
    },
    "fr": {
        "relative_dates": (
            "demain", "hier", "aujourd'hui", "la semaine prochaine", "la semaine dernière",
            "cette semaine", "le mois prochain", "le mois dernier", "bientôt", "récemment",
            "prochainement", "dans quelques jours",
        ),
        "opinion_markers": (
            "reconstruit", "je pense", "probablement", "il semble", "apparemment", "peut-être",
        ),
    },
}

# W1's scope (spec Sec4.4 check 5): the living files and the knowledge base.
# outbound/ is out of scope -- a mail may well say "tomorrow" to its reader.
RELATIVE_DATE_DIRS = (LIVING_DIR, "knowledge")

# Severities and exit codes (D-02, D-04, P-08).
ERROR = "ERROR"
WARNING = "WARNING"
EXIT_CLEAN = 0
EXIT_ERRORS = 1
EXIT_NO_DOSSIER = 2
EXIT_INTERNAL = 3

_KEY_RE = re.compile(r"([A-Za-z_][A-Za-z0-9_-]*):(?:[ \t]+(.*))?")

# The three keys that gate the confidential-name check E5 (spec Sec3.2,
# T-02-02). A dossier.yaml line the subset cannot read is an ERROR [C1],
# never a WARNING [C0], whatever key it seems to sit under (CR-01): a warning
# exits 0, and which key an unreadable line really belonged to is a guess --
# the lost line may be the whole name list, E5 silently off. So every
# skipped line fails closed, and a gate key is named in the message when one
# can be read off the line.
GATE_KEYS = frozenset(("confidential_names", "consent_recorded", "consent_source"))

# How close an unknown key must be to a gate key to be read as a misspelling
# of it (difflib ratio, WR-01). `confidental_names` scores 0.97; every other
# key of spec Sec3.2 (and name/role/contacts) scores under 0.5. A near-miss
# is C1 only while the gate key it resembles is absent from the top level
# (D-22, D-GAP-1, 2026-09-25 UAT G-02-2): a legitimate extension key such as
# `consent_scope` or `confidential_notes` sitting beside the exact gate key
# is a different, known key, and is ignored -- not every near-miss is an
# error. Exception (gap closure option (a), arbitrage Samuel, relayed by the
# main session via SendMessage, 2026-09-25): a `confidential_names` near-miss
# that is itself a probable typo -- see CONFIDENTIAL_NAMES_TYPO_CUTOFF below
# -- stays C1 even while the exact key is present, because leaking the
# confidential names it lists is the one failure this gate exists to
# prevent. consent_recorded and consent_source keep the presence exemption
# unconditionally.
GATE_KEY_CUTOFF = 0.8

# How a `confidential_names` near-miss earns the exception above: its OSA
# (Optimal String Alignment) distance to "confidential_names" -- Levenshtein
# plus a single adjacent-transposition edit -- must be <= this cutoff.
# Plain Levenshtein cannot separate a typo from a legitimate different key:
# `confidentail_names` (transposed "ai"/"ia") and `confidential_notes` (a
# real, different key from the gate-key-extras fixture) are BOTH Levenshtein
# distance 2 from `confidential_names` -- two substitutions either way.
# Scoring the transposition as one edit instead of two separates them
# cleanly: `confidentail_names` becomes OSA distance 1 (a typo), while
# `confidential_notes` stays at OSA distance 2 (o/t vs a/m, no beneficial
# transposition) and keeps its presence exemption, same as
# `non_confidential_names` (OSA distance 4). Cutoff 1 is therefore "one
# keystroke away downstream of _fold_key" -- a single substitution,
# insertion, deletion, or adjacent swap.
CONFIDENTIAL_NAMES_TYPO_CUTOFF = 1

# Gap closure CR-02 bis (arbitrage Samuel, relayed by the main session via
# SendMessage, 2026-09-25): CONFIDENTIAL_NAMES_TYPO_CUTOFF alone lets a
# double typo in the LAST `_`-separated word through, because it costs two
# edits against the full key while still obviously meaning "name(s)" --
# `confidential_nam` (missing "es") and `confidental_name` (missing "i" in
# "confidential" AND the trailing "s" of "names") both score OSA distance 2
# against "confidential_names", the same distance as the legitimate
# `confidential_notes`. The two are told apart by looking at the last word
# alone: `confidential_notes`' last word is "notes" (OSA 2 from "names", OSA
# 3 from "name"), while "nam" and "name" are each OSA <= 1 from "name" or
# "names". So a near-miss also stays C1 when its whole-key OSA distance is
# <= this looser cutoff AND its last `_`-separated word is within
# CONFIDENTIAL_NAMES_WORD_CUTOFF of "name" or "names" -- see
# _forces_c1_despite_presence().
CONFIDENTIAL_NAMES_TYPO_CUTOFF_WORD = 2

# Checked against BOTH "name" and "names" (not "names" alone), because a
# key's last word may itself be missing the trailing "s": `confidential_nam`
# has last word "nam", OSA distance 2 from "names" (insert "e", insert "s")
# but only 1 from "name" (insert "e"). Reading "within 1 of names" alone
# would miss it and let it through unflagged, which is not what Samuel's
# arbitrage asks for.
CONFIDENTIAL_NAMES_WORD_CUTOFF = 1

# Which key an UNREADABLE line belongs to, used to word the C1 message.
# Looser than _KEY_RE on purpose: it accepts a quoted key and no space after
# the colon, and a gate key with its colon forgotten still counts as that key.
_LOOSE_KEY_RE = re.compile(r"""["']?([A-Za-z_][A-Za-z0-9_-]*)["']?[ \t]*:""")
_GATE_KEY_START_RE = re.compile(
    r"""["']?(""" + "|".join(sorted(GATE_KEYS)) + r""")(?![A-Za-z0-9_-])""")
_INT_RE = re.compile(r"[-+]?[0-9]+")
_LAST_UPDATED_RE = re.compile(r"^[ \t]*Last updated:[ \t]*(.*)$")
_DATE_PREFIX_RE = re.compile(r"([0-9]{4})-([0-9]{2})-([0-9]{2})(?![0-9])")

# W2 (D-18): a bullet is a stripped line starting `- ` or `* `; it is sourced
# when it ends with one parenthesised run holding no nested parenthesis,
# optionally followed by a full stop and trailing whitespace.
_BULLET_PREFIXES = ("- ", "* ")
_PAREN_SOURCE_RE = re.compile(r"\([^()]+\)\.?\s*$")
_COMMENT_OPEN = "<!--"
_COMMENT_CLOSE = "-->"

# An absolute date, whole value: YYYY-MM-DD with ASCII digits only ([0-9],
# never \d, which also accepts other scripts' digits). Shape only: the
# calendar is is_absolute_date()'s job.
_DATE_RE = re.compile(r"([0-9]{4})-([0-9]{2})-([0-9]{2})")

# An outbound filename (D-10, A-03): YYYY-MM-DD, `_`, a slug of lowercase
# ASCII letters and digits joined by single hyphens, `.`, an extension. The
# slug charset borrows knowledge/decisions/'s convention; it rejects
# uppercase and a second `_` inside the slug, which is the assumption most
# likely to need loosening after real use. Always fullmatch'ed, never `$`,
# which would accept a name ending in a newline.
_OUTBOUND_NAME_RE = re.compile(r"([0-9]{4}-[0-9]{2}-[0-9]{2})_[a-z0-9]+(?:-[a-z0-9]+)*\.[A-Za-z0-9]+")

# One status-header line, whatever the comment syntax around it (D-07,
# Pattern 4). Only non-alphanumeric characters may precede the field name
# (`<!-- `, `# `, `// `, indentation), so a prose line such as "Reply To: x"
# is not a header line; a trailing HTML comment closer is dropped from the
# value. Built from PROTOCOL_FIELDS: no per-language label table exists.
_FIELD_RE = re.compile(
    r"[^A-Za-z0-9]*?\b(" + "|".join(re.escape(field) for field in PROTOCOL_FIELDS)
    + r"):[ \t]*(.*?)[ \t]*(?:-->)?[ \t]*"
)

# The three valid status values (D-08). `reviewed by` and `sent ... by` need
# a non-empty name; `sent` needs an absolute date, optionally a time.
_STATUS_REVIEWED_RE = re.compile(r"reviewed by[ \t]+\S.*")
_STATUS_SENT_RE = re.compile(
    r"sent[ \t]+([0-9]{4}-[0-9]{2}-[0-9]{2})"
    r"(?:[ \t]+(?:[01]?[0-9]|2[0-3]):[0-5][0-9](?::[0-5][0-9])?)?"
    r"[ \t]+by[ \t]+\S.*"
)

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
    doubled = False
    for i, ch in enumerate(line):
        if doubled:
            doubled = False
            continue
        if quote:
            out.append(ch)
            if escaped:
                escaped = False
            elif quote == '"' and ch == "\\":
                escaped = True
            elif quote == "'" and ch == "'" and line[i + 1:i + 2] == "'":
                # `''` is the single-quoted scalar's one escape (WR-01): an
                # apostrophe, not the closing quote.
                out.append(ch)
                doubled = True
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
    if text in ("-", "?", ":") or text[:2] in ("- ", "? ", ": ", "-\t", "?\t", ":\t"):
        # `- - Acme` is a list inside a list in YAML; read as the plain
        # scalar `- Acme`, a name would never match (WR-01).
        raise ValueError("nested collection outside the supported YAML subset")
    if ": " in text or ":\t" in text or text.endswith(":"):
        # Not a plain scalar in YAML: most likely two lines joined, the
        # second one a key the schema would never see (WR-01).
        raise ValueError("`: ` inside a plain scalar")
    return Scalar(text, False, line)


def _split_flow(inner):
    """Split the inside of `[ a, "b, c" ]` on the commas outside quotes."""
    items = []
    buf = []
    quote = None
    escaped = False
    doubled = False
    for i, ch in enumerate(inner):
        if doubled:
            doubled = False
            continue
        if quote:
            buf.append(ch)
            if escaped:
                escaped = False
            elif quote == '"' and ch == "\\":
                escaped = True
            elif quote == "'" and ch == "'" and inner[i + 1:i + 2] == "'":
                buf.append(ch)  # `''`: an escaped apostrophe, the quote stays open (WR-01)
                doubled = True
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


def _is_seq_item(body):
    """True when a stripped line is a block-sequence item (`-` or `- ...`)."""
    return body == "-" or body.startswith("- ")


def _owning_key(body, previous):
    """The top-level key an unreadable column-0 line belongs to (CR-01).

    Its own key when it has one (quoted, or with no space after the colon);
    a gate key whose colon was forgotten; otherwise the key above it, since a
    column-0 line with no key of its own is the continuation of that key's
    value (the `]` closing a multi-line flow sequence, a stray item).
    """
    match = _LOOSE_KEY_RE.match(body) or _GATE_KEY_START_RE.match(body)
    return match.group(1) if match is not None else previous


def _fold_key(text):
    """A key as a person means it: casefolded, hyphens and spaces as `_`."""
    return re.sub(r"[\s-]+", "_", text.strip().casefold())


def gate_key_for(key):
    """The gate key KEY spells, exactly or nearly, else None.

    Nearly: after _fold_key (`Confidential-Names`), or within
    GATE_KEY_CUTOFF of one (`confidental_names`). A key that is not the
    exact spelling is never READ as the gate -- the caller reports it.
    `_skipped_key()` uses this to word an unreadable line's message; that
    line is C1 whatever the wording (D-FIX-8). `_misplaced_gate_keys()`
    applies its own presence rule on top of this call (D-22, D-GAP-1): a
    near-miss is reported only while the exact gate key is absent.
    """
    folded = _fold_key(key)
    if folded in GATE_KEYS:
        return folded
    close = difflib.get_close_matches(folded, sorted(GATE_KEYS), n=1, cutoff=GATE_KEY_CUTOFF)
    return close[0] if close else None


def _certain_gate_key_for(key):
    """The gate key KEY certainly spells: equal to it after _fold_key, else None.

    A case, hyphen or space variant of a gate key (`Confidential-Names`,
    `confidential-names`) always means that gate key, whatever else is
    present in the config (D-GAP-1) -- unlike a difflib-only near-miss,
    which `gate_key_for()` also returns but which `_misplaced_gate_keys()`
    reports only while the exact gate key is absent.
    """
    folded = _fold_key(key)
    return folded if folded in GATE_KEYS else None


def _osa_distance(a, b):
    """Optimal String Alignment distance between A and B: Levenshtein plus a
    single adjacent-transposition edit, stdlib-only DP (no import beyond
    what the module already uses). Each character participates in at most
    one transposition -- the "restricted" variant, simpler than full
    Damerau-Levenshtein and sufficient for scoring a one-keystroke typo.
    """
    m, n = len(a), len(b)
    d = [[0] * (n + 1) for _ in range(m + 1)]
    for i in range(m + 1):
        d[i][0] = i
    for j in range(n + 1):
        d[0][j] = j
    for i in range(1, m + 1):
        for j in range(1, n + 1):
            cost = 0 if a[i - 1] == b[j - 1] else 1
            d[i][j] = min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost)
            if i > 1 and j > 1 and a[i - 1] == b[j - 2] and a[i - 2] == b[j - 1]:
                d[i][j] = min(d[i][j], d[i - 2][j - 2] + 1)
    return d[m][n]


def _forces_c1_despite_presence(key, near):
    """True when a `confidential_names` near-miss stays C1 even though the
    exact gate key is present in `raw` (gap closure option (a), arbitrage
    Samuel, relayed by the main session via SendMessage, 2026-09-25; refined
    CR-02 bis, same arbitrage channel, same date, option (2)).

    Only near-misses of `confidential_names` are ever forced; `consent_
    recorded` and `consent_source` near-misses keep the unconditional
    presence exemption from D-22 (a legitimate extension key beside the
    exact gate key stays silent). A `confidential_names` near-miss is forced
    when, on the folded key:

    - its whole-key OSA distance to "confidential_names" is <=
      CONFIDENTIAL_NAMES_TYPO_CUTOFF (a single-keystroke typo anywhere in
      the key, `confidentail_names`, `confidentialnames`), OR
    - its whole-key OSA distance is <= CONFIDENTIAL_NAMES_TYPO_CUTOFF_WORD
      AND its last `_`-separated word is within CONFIDENTIAL_NAMES_WORD_
      CUTOFF of "name" OR "names" (a double typo concentrated in the word
      that says what the key holds, `confidental_name`, `confidential_nam`).

    The first clause alone is kept (not folded into the second) because it
    is what still catches `confidentialnames`, which has no `_` and so no
    last word to test.

    The second clause checks "name" as well as "names" because a key's last
    word may itself be missing the plural: `confidential_nam` has last word
    "nam", OSA distance 2 from "names" but only 1 from "name" -- "within 1
    of names" alone would miss it. Checking both is what separates a typo of
    "name(s)" from a different, legitimate word: `confidential_notes`' last
    word "notes" is OSA distance 2 from "names" and 3 from "name", so it
    stays outside the word cutoff and keeps its presence exemption, same as
    `non_confidential_names` (whole-key OSA distance 4, outside even the
    looser cutoff).

    Residual limit (documented, not fixed here): a double typo INSIDE the
    last word that still lands within 2 keystrokes of "name"/"names" only
    by chance is not specifically hunted beyond this rule -- e.g.
    `confidential_nmes` (transposed "am"/"ma", OSA 1 from "names") is
    actually still caught by the first clause; a harder case such as a
    last word two-or-more keystrokes from both "name" and "names" is, by
    design, read as a different key and ignored, per 02-CONTEXT.md.
    """
    if near != "confidential_names":
        return False
    folded = _fold_key(key)
    whole = _osa_distance(folded, near)
    if whole <= CONFIDENTIAL_NAMES_TYPO_CUTOFF:
        return True
    if whole <= CONFIDENTIAL_NAMES_TYPO_CUTOFF_WORD:
        last_word = folded.rsplit("_", 1)[-1]
        if (_osa_distance(last_word, "name") <= CONFIDENTIAL_NAMES_WORD_CUTOFF
                or _osa_distance(last_word, "names") <= CONFIDENTIAL_NAMES_WORD_CUTOFF):
            return True
    return False


def _skipped_key(body, owner):
    """The key an unreadable line is reported under, for the message (CR-01).

    The line's own key first, when it spells a gate key: an indented
    `confidential_names:` line under counterparts is about the names, not
    about counterparts. Then a gate key written anywhere on the line (two
    lines joined, a key with a space in it). Otherwise the top-level key
    above it.
    """
    own = _LOOSE_KEY_RE.match(body) or _GATE_KEY_START_RE.match(body)
    if own is not None and gate_key_for(own.group(1)) is not None:
        return gate_key_for(own.group(1))
    folded = _fold_key(body)
    for key in sorted(GATE_KEYS):
        if key in folded:
            return key
    return owner


class _DuplicateKey(ValueError):
    """A top-level key seen a second time.

    `certain` is True when the line is otherwise well formed (its value
    parses): the one skipped line whose meaning is known exactly, and so the
    one that may stay a warning when the key is not a gate key.
    """

    def __init__(self, certain):
        ValueError.__init__(self, "duplicate key")
        self.certain = certain


def yaml_lines(text):
    """dossier.yaml's lines, split on \\r\\n, \\r and \\n only (CR-02).

    Never str.splitlines(): it also breaks on U+0085, U+2028 and U+2029,
    which YAML 1.2 and the producer treat as ordinary characters. Split
    there, a quoted name holding one cuts its line in two and every name on
    the line is lost.
    """
    return text.replace("\r\n", "\n").replace("\r", "\n").split("\n")


def parse_yaml_subset(text, skipped=None):
    """Parse the dossier.yaml subset into Scalar / Seq / Map values.

    Supported (D-22, D-24.1): `key: value`, flow sequences `[ a, b ]`, block
    sequences `- item` (indented, or at column 0 right under their key),
    block sequences of mappings (`counterparts`), a one-level nested
    mapping, `#` comments (quote-aware), single and double quotes. No
    implicit int/bool/null/float/date conversion happens here: every scalar
    comes back as its raw text plus a `quoted` flag, and apply_schema()
    alone decides a field's type. A line outside the subset is skipped and
    `(number, key, reason, certain)` appended to `skipped` -- never a crash.
    `key` is the line's own gate key when it carries one, else the top-level
    key above it (None when there is none); `certain` is True only for a
    well-formed duplicate of a top-level key, so the caller fails closed on
    every other skipped line (CR-01). A top-level key seen a second time is
    skipped: the first occurrence wins, and a conforming YAML parser would
    have rejected the file.
    """
    data = {}
    block_key = None
    block_indent = -1
    item = None
    item_indent = -1
    owner = None
    for number, raw in enumerate(yaml_lines(text), 1):
        line = strip_comment(raw)
        body = line.strip()
        if not body or body in ("---", "..."):
            continue
        indent = len(line) - len(line.lstrip(" \t"))
        top_level = indent == 0 and not (block_key is not None and _is_seq_item(body))
        if top_level:
            owner = _owning_key(body, owner)
        try:
            if top_level:
                block_key, block_indent, item = None, -1, None
                match = _KEY_RE.fullmatch(body)
                if match is None:
                    raise ValueError("not a `key: value` line")
                key, value = match.group(1), match.group(2)
                if key in data:
                    try:
                        _value_or_empty(value, number)
                    except ValueError:
                        raise _DuplicateKey(False)
                    raise _DuplicateKey(True)
                if value is None or value.strip() == "":
                    data[key] = Scalar("", False, number)
                    block_key = key
                else:
                    data[key] = parse_value(value.strip(), number)
                continue
            if block_key is None:
                raise ValueError("indented line outside a block")
            current = data[block_key]
            if _is_seq_item(body):
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
        except ValueError as exc:
            if skipped is not None:
                certain = isinstance(exc, _DuplicateKey) and exc.certain
                skipped.append((number, _skipped_key(body, owner), str(exc), certain))
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
        # Pinned by the c1-yes/c1-quoted fixtures (no E6 follows) and by
        # c1-quoted-leak (C1 and E5 together: the leak check still fires).
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


def _misplaced_gate_keys(raw, findings):
    """C1 for every key that certainly spells a gate key without being it,
    or that only resembles one while the exact key is absent (D-22, D-GAP-1,
    2026-09-25 UAT G-02-2).

    The presence rule applies at every depth (top level and, through
    visit(), any nesting below it). Let G be the gate key a key resembles:

    - A key equal to G after _fold_key (case, `-`, space -- `confidential-
      names`, `Confidential_names`) certainly means G, and is reported
      whatever else is present in the config.
    - A key that only difflib-resembles G (`confidental_names`) is reported
      only while G is not itself a key of `raw`, the top-level mapping the
      parser produced. When G is present, the near-miss is a different,
      legitimate key (`consent_scope` beside `consent_source`) and D-22
      ignores it -- at every depth, so a counterpart-level `confidential_
      notes` beside a top-level `confidential_names` is silent too.
    - Exception (gap closure option (a), 2026-09-25): a near-miss of
      `confidential_names` specifically is reported even while the exact
      key is present, when `_forces_c1_despite_presence()` judges it a
      probable typo (OSA distance <= CONFIDENTIAL_NAMES_TYPO_CUTOFF) rather
      than a legitimate different key such as `confidential_notes`.
      `consent_recorded` and `consent_source` near-misses keep the
      unconditional presence exemption.
    - A key exactly equal to a gate key at the top level is never reported
      (unchanged).

    Returns True when at least one key was reported, so the caller keeps
    `config["gate_damaged"]` -- and with it E5 -- armed exactly then.
    """
    found = False

    def visit(value, where):
        nonlocal found
        if isinstance(value, dict):
            for key, entry in value.items():
                certain = _certain_gate_key_for(key)
                if certain is not None:
                    found = True
                    findings.append(Finding(CONFIG_NAME, _line_of(entry), ERROR, "C1",
                                            "{} is written under {}: it is read only at the top level, "
                                            "the confidentiality gate fails closed".format(certain, where)))
                else:
                    near = gate_key_for(key)
                    if near is not None and (near not in raw or _forces_c1_despite_presence(key, near)):
                        found = True
                        findings.append(Finding(CONFIG_NAME, _line_of(entry), ERROR, "C1",
                                                "'{}' at {} looks like a misspelling of {}, which is read "
                                                "only at the top level: the confidentiality gate fails "
                                                "closed until it is corrected".format(key, where, near)))
                visit(entry, where + "." + key)
        elif isinstance(value, list):
            for entry in value:
                visit(entry, where + "[]")

    for key, value in raw.items():
        if key not in GATE_KEYS:
            gate = _certain_gate_key_for(key)
            if gate is None:
                near = gate_key_for(key)
                if near is not None and (near not in raw or _forces_c1_despite_presence(key, near)):
                    gate = near
            if gate is not None:
                found = True
                findings.append(Finding(CONFIG_NAME, _line_of(value), ERROR, "C1",
                                        "key '{}' looks like a misspelling of {}: it is not read as the "
                                        "gate, the confidentiality gate fails closed until it is "
                                        "corrected".format(key, gate)))
        visit(value, key)
    return found


def apply_schema(raw, findings):
    """Type every field the linter reads; emit C1 on a malformed one.

    The per-field typing authority (D-24.2). Unknown keys are ignored (D-22),
    except a key that spells a gate key without being it (WR-01). Every
    reader returns a safe default after reporting, so one malformed field
    never hides the findings of the rest of the dossier.
    """
    config = {"gate_damaged": _misplaced_gate_keys(raw, findings)}
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
    config["consent_source_empty"] = source_is_empty(source)
    config["consent_line"] = _line_of(source if source is not None else raw.get("consent_recorded"))
    return config


def source_is_empty(value):
    """True when a raw consent_source names no source at all (WR-02, D-24).

    Absent, not a single string, blank, an unquoted YAML null (`null`, `~`),
    or text with no letter and no digit (`-`, `?`, `...`): each is the
    "true without a source" the spec calls a lint error, and every ambiguity
    of this gate resolves on the strict side.
    """
    if not isinstance(value, Scalar):
        return True
    text = value.text.strip()
    if text == "" or (not value.quoted and text in NULL_SCALARS):
        return True
    return not any(ch.isalnum() for ch in text)


def consent_is_recorded(config):
    """True only when the flag is true AND a source is filled in (spec Sec3.2).

    The one condition under which the confidential-name check (E5) is
    suppressed -- and never while any dossier.yaml line was unreadable, or a
    gate key duplicated (CR-01): what the file really says is unknown, so
    the check stays armed.
    """
    if config.get("gate_damaged"):
        return False
    return config["consent_recorded"] and not config["consent_source_empty"]


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
    gate_damaged = False
    if text.lstrip()[:1] == "{":
        duplicates = []

        def keep_first(pairs):
            # json.loads keeps the LAST of two equal keys, silently: a second,
            # empty confidential_names would switch E5 off (CR-01).
            obj = {}
            for key, value in pairs:
                if key in obj:
                    duplicates.append(key)
                else:
                    obj[key] = value
            return obj

        try:
            obj = json.loads(text, object_pairs_hook=keep_first)
        except ValueError as exc:
            findings.append(Finding(CONFIG_NAME, getattr(exc, "lineno", 0), ERROR, "C1",
                                    "dossier.yaml starts with `{` but is not valid JSON"))
            obj = {}
        if not isinstance(obj, dict):
            findings.append(Finding(CONFIG_NAME, 0, ERROR, "C1", "dossier.yaml JSON must be an object"))
            obj = {}
        for key in duplicates:
            if key in GATE_KEYS:
                gate_damaged = True
                findings.append(Finding(CONFIG_NAME, 0, ERROR, "C1",
                                        "duplicate key {} (the confidentiality gate fails closed)".format(key)))
            else:
                findings.append(Finding(CONFIG_NAME, 0, WARNING, "C0",
                                        "duplicate key {}: the first one is read".format(key)))
        raw = json_to_scalars(obj)
    else:
        skipped = []
        raw = parse_yaml_subset(text, skipped)
        for number, key, reason, certain in skipped:
            if certain and key not in GATE_KEYS:
                # A well-formed repeat of a non-gate key: its meaning is
                # known exactly, and the first occurrence is read (D-22).
                findings.append(Finding(CONFIG_NAME, number, WARNING, "C0",
                                        "line {} skipped: duplicate key {}, the first one is read".format(
                                            number, key)))
                continue
            # Fail closed (CR-01): which key an unreadable line really
            # belonged to is a guess, and it may have held the names or the
            # consent -- so it can never be a mere warning, and the leak
            # check stays armed whatever the consent flag says.
            gate_damaged = True
            if key in GATE_KEYS:
                findings.append(Finding(CONFIG_NAME, number, ERROR, "C1",
                                        "line {} skipped ({}) on the confidentiality gate key {}: "
                                        "fix it, the leak check cannot trust it".format(number, reason, key)))
            else:
                findings.append(Finding(CONFIG_NAME, number, ERROR, "C1",
                                        "line {} skipped ({}, outside the supported YAML subset): "
                                        "fix it, the confidentiality gate fails closed until then".format(
                                            number, reason)))
    config = apply_schema(raw, findings)
    config["gate_damaged"] = config["gate_damaged"] or gate_damaged
    return config


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
    """The result of the single walk: POSIX paths relative to the root.

    `pruned` lists the sub-dossiers skipped as D-03 boundaries, each named
    on an info line so a skipped subtree is never silent (WR-03).
    `symlinks` lists the directory symlinks the walk did not follow
    (T-02-03): an E1 error under outbound/, an info line elsewhere (WR-02).
    `unreadable` lists the folders os.walk could not list at all (a
    permission error from os.scandir): an E1 error under outbound/, an info
    line elsewhere (D-GAP-3, G-02-4e) -- never dropped in silence, the same
    treatment as a symlink. `git_dirs` lists the `.git` folders met inside
    the fixed layout: still never descended into (walking a repository's
    object store would otherwise bury the finding under one per object
    file), but recorded and reported the same way as `unreadable`.
    """

    __slots__ = ("files", "dirs", "file_set", "pruned", "symlinks", "unreadable", "git_dirs",
                 "gitkeeps")

    def __init__(self, files, dirs, pruned=(), symlinks=(), unreadable=(), git_dirs=(), gitkeeps=()):
        self.files = files
        # The NON-EMPTY `.gitkeep` files under outbound/ (A5-F8, 05 D-09): an
        # empty one is the placeholder LINT-01 ignores, one holding bytes is
        # a document like any other. Kept out of `files`, so E1-E4 and E9
        # never see it; only E5 reads it.
        self.gitkeeps = list(gitkeeps)
        self.dirs = dirs
        self.file_set = frozenset(files)
        self.pruned = list(pruned)
        self.symlinks = list(symlinks)
        self.unreadable = list(unreadable)
        self.git_dirs = list(git_dirs)


def walk_tree(root):
    """One pruned, sorted, read-only os.walk pass over the dossier (D-03).

    Pruning is a slice-assignment of `dirnames[:]` while still in the parent
    (the documented os.walk idiom): `.git` is dropped, and so is every child
    directory that itself holds a dossier.yaml -- a nested dossier is a
    boundary, never descended into and never merged into this one's findings.
    Directory symlinks are listed but never followed (the os.walk default,
    deliberately not overridden -- T-02-03: a link may point outside the
    dossier, or back up into it); each one is recorded in `symlinks` so it
    is reported, never silently skipped (WR-02). `.gitkeep` is dropped
    everywhere (LINT-01), except that a non-empty one under outbound/ is
    recorded in `gitkeeps` for E5 (A5-F8). A dossier.yaml inside the fixed layout (LAYOUT_DIRS)
    is not a boundary: that folder is walked as usual, and under outbound/
    the stray file meets the outbound checks like any other (WR-03).

    A folder os.scandir cannot list raises inside os.walk; the `onerror`
    callback records its path in `unreadable` instead of the default
    (silent drop, D-GAP-3, G-02-4e) -- it was already listed as an entry of
    its parent, so it still shows up in `dirs`, just with none of its own
    children walked. `.git` is still never descended into anywhere, but a
    `.git` met inside the fixed layout is recorded in `git_dirs` rather than
    dropped in silence like one met outside it (D-GAP-3).
    """
    files = []
    dirs = []
    pruned = []
    symlinks = []
    unreadable = []
    git_dirs = []
    gitkeeps = []

    def _onerror(err):
        unreadable.append(os.path.relpath(err.filename, root).replace(os.sep, "/"))

    for dirpath, dirnames, filenames in os.walk(root, topdown=True, onerror=_onerror):
        dirnames.sort()
        filenames.sort()
        rel_dir = os.path.relpath(dirpath, root)
        prefix = "" if rel_dir == os.curdir else rel_dir.replace(os.sep, "/") + "/"
        in_layout = prefix.split("/", 1)[0].casefold() in _LAYOUT_DIRS_FOLDED
        kept = []
        for name in dirnames:
            if name in PRUNED_DIRS:
                if in_layout:
                    git_dirs.append(prefix + name)
                continue
            if (not in_layout and not (prefix == "" and name.casefold() in _LAYOUT_DIRS_FOLDED)
                    and os.path.isfile(os.path.join(dirpath, name, CONFIG_NAME))):
                pruned.append(prefix + name)
                continue
            kept.append(name)
        dirnames[:] = kept
        for name in dirnames:
            dirs.append(prefix + name)
            if os.path.islink(os.path.join(dirpath, name)):
                symlinks.append(prefix + name)
        for name in filenames:
            if name != GITKEEP:
                files.append(prefix + name)
            elif _in_outbound(prefix + name):
                try:
                    # lstat: a symlinked .gitkeep is measured as the link itself.
                    if os.lstat(os.path.join(dirpath, name)).st_size > 0:
                        gitkeeps.append(prefix + name)
                except OSError:
                    pass
    return Tree(files, dirs, pruned, symlinks, unreadable, git_dirs, gitkeeps)


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


def is_absolute_date(text):
    """True when TEXT is exactly YYYY-MM-DD and a real calendar date (D-09).

    The calendar is the standard library's, never a month-length table, so
    2026-13-45 and 2026-02-30 are rejected. Shared by E2 (the sent date), E3
    (Deadline:) and E4 (the filename date).
    """
    match = _DATE_RE.fullmatch(text)
    return match is not None and _is_real_date(*match.groups())


def _in_outbound(rel):
    return rel == OUTBOUND_DIR or rel.startswith(OUTBOUND_DIR + "/")


def outbound_files(tree):
    """Every walked file under outbound/, in walk order (`.gitkeep` already gone)."""
    prefix = OUTBOUND_DIR + "/"
    return [rel for rel in tree.files if rel.startswith(prefix)]


def _is_header_target(rel):
    """E1-E3 scope (D-07): outbound files minus the exempt README and binaries."""
    name = rel.rsplit("/", 1)[-1]
    if rel in EXEMPT_PATHS:  # D-06: outbound/README.md quotes the header verbatim
        return False
    if name in OS_METADATA_NAMES:  # WR-05
        return False
    return os.path.splitext(name)[1].lower() not in BINARY_EXTS


# ---------------------------------------------------------------------------
# CHECKS -- in identifier order. Each takes (root, tree, config, findings).
# ---------------------------------------------------------------------------


def read_status_header(text):
    """{field: (line, value)} from the first STATUS_HEADER_WINDOW lines.

    First occurrence of each field wins, and nothing below the window is
    read, so a mail body quoting an older header cannot fire (P-06).
    """
    header = {}
    for number, line in enumerate(text.splitlines()[:STATUS_HEADER_WINDOW], 1):
        match = _FIELD_RE.fullmatch(line)
        if match is not None and match.group(1) not in header:
            header[match.group(1)] = (number, match.group(2))
    return header


def _status_problem(value):
    """None when VALUE is a valid status (D-08), else the E2 message."""
    if value == "draft" or _STATUS_REVIEWED_RE.fullmatch(value):
        return None
    if value.startswith("reviewed by") or value == "reviewed":
        return "reviewed by status without a name"
    if value == "sent" or value.startswith(("sent ", "sent\t")):
        match = _STATUS_SENT_RE.fullmatch(value)
        if match is not None and is_absolute_date(match.group(1)):
            return None
        return "sent status without an absolute date or a sender (sent YYYY-MM-DD [HH:MM] by <name>)"
    return "status must be draft, reviewed by <name>, or sent YYYY-MM-DD [HH:MM] by <name>"


def check_outbound_headers(root, tree, config, findings):
    """E1, E2, E3: the status block every outbound file opens with (D-07..D-09).

    E1: no recognised field in the first STATUS_HEADER_WINDOW lines (line 0),
    or a required field missing or empty (at the first header line). E2: an
    incomplete status value. E3: a Deadline: that is not an absolute, real
    date. The field names are grepped in English in every dossier (spec
    Sec3.2); there is no per-format parser and no per-language label table.
    A symlinked folder under outbound/ (or outbound/ itself) is E1 too: the
    walk does not follow it (T-02-03), so none of E1-E5 reached its files,
    and a leak check that did not run must not exit 0 (WR-02). The same
    rule covers a folder spelt as a case variant of a fixed layout name, or
    of an OUTBOUND_SUBS name directly under outbound/ (D-GAP-2, CR-01,
    G-02-4a): on a case-insensitive filesystem it is the very folder an
    agent writes to, yet none of E1-E5 would otherwise read it. Two more
    routes to the same failure (D-GAP-3, G-02-4e): a folder os.walk could
    not list at all, and a `.git` folder met inside the fixed layout -- both
    are never walked, so under outbound/ both are E1 too.
    """
    for rel in tree.symlinks:
        if _in_outbound(rel):
            findings.append(Finding(rel, 0, ERROR, "E1",
                                    "folder is a symlink, never followed: none of its files is checked "
                                    "(status header, name, confidential names); make it a real folder"))
    for rel in tree.unreadable:
        if _in_outbound(rel):
            findings.append(Finding(rel, 0, ERROR, "E1",
                                    "folder cannot be read: none of its files is checked (status header, "
                                    "name, confidential names); fix its permissions"))
    for rel in tree.git_dirs:
        if _in_outbound(rel):
            findings.append(Finding(rel, 0, ERROR, "E1",
                                    "folder is a .git folder, never walked: none of its files is checked "
                                    "(status header, name, confidential names); move it out of outbound/"))
    for rel in tree.dirs:
        parent, _, name = rel.rpartition("/")
        expected = LAYOUT_DIRS if parent == "" else (OUTBOUND_SUBS if parent == OUTBOUND_DIR else ())
        for fixed in sorted(expected):
            if name != fixed and name.casefold() == fixed.casefold():
                findings.append(Finding(rel, 0, ERROR, "E1",
                                        "folder is spelt {} but the layout name is {}: none of its files "
                                        "is checked (status header, name, confidential names); rename it "
                                        "(git mv, in two steps on a case-insensitive filesystem)".format(
                                            name, fixed)))
    for rel in outbound_files(tree):
        if not _is_header_target(rel):
            continue
        text = read_text_safe(os.path.join(root, *rel.split("/")))
        if text is None:
            findings.append(Finding(rel, 0, ERROR, "E1",
                                    "outbound file cannot be read (symlink, over 5 MB, or not UTF-8), "
                                    "so it has no readable status header"))
            continue
        header = read_status_header(text)
        if not header:
            findings.append(Finding(rel, 0, ERROR, "E1",
                                    "no status header in the first {} lines".format(STATUS_HEADER_WINDOW)))
            continue
        required = MAIL_REQUIRED_FIELDS if rel.startswith(OUTBOUND_DIR + "/mails/") else REQUIRED_FIELDS
        missing = [field for field in required
                   if field not in header or (field != "Status" and header[field][1] == "")]
        if missing:
            first_line = min(line for line, _value in header.values())
            findings.append(Finding(rel, first_line, ERROR, "E1", "incomplete status header: missing {}".format(
                ", ".join(field + ":" for field in missing))))
        if "Status" in header:
            line, value = header["Status"]
            problem = _status_problem(value)
            if problem is not None:
                findings.append(Finding(rel, line, ERROR, "E2", problem))
        if "Deadline" in header:
            line, value = header["Deadline"]
            if not is_absolute_date(value):
                findings.append(Finding(rel, line, ERROR, "E3",
                                        "Deadline: is not an absolute YYYY-MM-DD date"))


def check_outbound_names(root, tree, config, findings):
    """E4: a file directly under outbound/{deliverables,mails,calls}/ is named
    YYYY-MM-DD_slug.ext with a real calendar date (D-10, A-03).

    Reported at line 0: the finding is about the file as a whole.
    """
    for rel in outbound_files(tree):
        parts = rel.split("/")
        if len(parts) != 3 or parts[1] not in OUTBOUND_SUBS:
            continue
        name = parts[2]
        if name == README_NAME or name in OS_METADATA_NAMES:  # D-10, WR-05
            continue
        match = _OUTBOUND_NAME_RE.fullmatch(name)
        if match is None or not is_absolute_date(match.group(1)):
            findings.append(Finding(rel, 0, ERROR, "E4",
                                    "filename does not match YYYY-MM-DD_slug.ext "
                                    "(real date, lowercase slug joined by hyphens)"))


# Matches nothing: the pattern for a needle with no token at all.
_NEVER_RE = re.compile(r"(?!)")


def boundary_pattern(needle):
    """A case-insensitive pattern matching NEEDLE as a whole name (D-11, F-02).

    Each whitespace-separated token is escaped first: it comes from
    dossier.yaml, and an unescaped one would let a hostile config inject a
    regex (T-02-05). The tokens are joined by `\\s+`, so a multi-word name
    still matches when a mail body is hard-wrapped between its words, or
    spaced with two spaces, a tab or a no-break space (CR-03); the caller
    searches the whole text, not one line at a time. The boundary is "a
    character that is alphanumeric but not `_`", i.e. [^\\W_], on both sides.
    The obvious (?<!\\w) counts `_` as a word character, and since every
    outbound filename is YYYY-MM-DD_slug, a name at the head of a slug would
    never match -- the silent miss measured on 2026-09-17_acme-proposal.md.
    This class still refuses `Acmetal`.
    """
    tokens = normalise(needle).split()
    if not tokens:
        return _NEVER_RE
    body = r"\s+".join(re.escape(token) for token in tokens)
    return re.compile(r"(?<![^\W_])" + body + r"(?![^\W_])", re.IGNORECASE)


# Letters NFKD leaves whole, so fold_ascii() would keep them non-ASCII and a
# name holding one could never match an E4-conforming slug (CR-03): a
# stroke, a slash, the ligatures, eth, thorn, the dotless i, the sharp s
# (casefold also turns ß into ss; listed for intent), the Maltese h.
# Transliterated to what a person typing an ASCII slug writes.
_FOLD_TABLE = str.maketrans({
    "Ł": "l", "ł": "l", "Ø": "o", "ø": "o", "Æ": "ae", "æ": "ae", "Œ": "oe", "œ": "oe",
    "Đ": "d", "đ": "d", "Ð": "d", "ð": "d", "Þ": "th", "þ": "th", "ı": "i",
    "ß": "ss", "ẞ": "ss", "Ħ": "h", "ħ": "h",
    # Every apostrophe look-alike folds to U+0027, the one the separator
    # classes below accept (A5-F2, 05 D-09): U+2018, U+2019, U+201B, the
    # modifier letter U+02BC (a letter to \w, so it would otherwise glue
    # `O` and `Brien` into one token), the grave U+0060, the acute U+00B4
    # (NFKD would turn it into a space), the primes U+2032 and U+2035.
    # The absence of an apostrophe needs no entry: the separator is optional.
    "‘": "'", "’": "'", "‛": "'", "ʼ": "'", "`": "'",
    "´": "'", "′": "'", "‵": "'",
})

# Homoglyphs (A5-F3, 05 D-09): letters of other scripts that a person -- or
# a hostile paste -- uses in place of a Latin one, drawn the same on screen
# (`Big Telсo` with a Cyrillic с). Applied by fold_ascii() to the NEEDLE and
# the haystack alike AFTER casefolding, so it lists lowercase letters only:
# the capitals casefold into them first. A small hand-picked table, not the
# full Unicode confusables list (not in the standard library): Cyrillic and
# Greek letters whose lowercase form is visually the Latin letter or a
# near-identical one, plus the Latin-script IPA g and a, the Cyrillic palochka
# and Greek lunate sigma. Folding both sides is the safe direction for a leak
# check: a Cyrillic needle folds the same way as its haystack. Abbreviations
# and acronyms (`BT` for `British Telecom`) are NOT covered: that is accepted
# v1 debt (05 D-09), left to the doctrine-reviewer alone.
_HOMOGLYPHS = str.maketrans({
    # Cyrillic
    "а": "a", "в": "b", "е": "e", "к": "k", "м": "m", "н": "h", "о": "o",
    "р": "p", "с": "c", "т": "t", "у": "y", "х": "x", "і": "i", "ј": "j",
    "ѕ": "s", "ԁ": "d", "һ": "h", "ԛ": "q", "ԝ": "w", "ӏ": "l", "ѵ": "v",
    "ӓ": "a", "ё": "e",
    # Greek
    "α": "a", "β": "b", "ε": "e", "ι": "i", "κ": "k", "ν": "v", "ο": "o",
    "ρ": "p", "τ": "t", "υ": "u", "χ": "x", "ω": "w", "η": "n", "ϲ": "c",
    "γ": "y", "μ": "u",
    # Latin-script look-alikes
    "ɡ": "g", "ɑ": "a",
})

# The second customary spelling of a letter, tried on the NEEDLE only:
# Serbian and Croatian Đ is written `d` or `dj` in ASCII (Đorđe: dorde,
# djordje), and either may be the slug.
_FOLD_ALTERNATES = str.maketrans({"Đ": "dj", "đ": "dj"})


def fold_ascii(text, alternate=False):
    """TEXT as an E4 slug would spell it (CR-03).

    The letters NFKD cannot decompose are transliterated first
    (_FOLD_TABLE; with `alternate`, _FOLD_ALTERNATES wins where it applies),
    then NFKD, combining marks dropped, casefolded, and the homoglyphs of
    other scripts mapped to their Latin look-alike (_HOMOGLYPHS, A5-F3);
    apostrophe look-alikes become U+0027 (A5-F2). E4 only accepts a
    lowercase ASCII slug, so `Société Exemple` can only appear in a
    conforming filename as `societe-exemple`, and `Łukasz` as `lukasz`.
    """
    if alternate:
        text = text.translate(_FOLD_ALTERNATES)
    decomposed = unicodedata.normalize("NFKD", text.translate(_FOLD_TABLE))
    # Judged once per DISTINCT character and deleted with one C-level pass:
    # the per-character generator this replaces dominated a 5 MB file.
    marks = {ord(ch): None for ch in set(decomposed) if unicodedata.combining(ch)}
    if marks:
        decomposed = decomposed.translate(marks)
    return decomposed.casefold().translate(_HOMOGLYPHS)


def filename_pattern(needle):
    """E5's pattern for a file NAME, matched against fold_ascii(path) (CR-03).

    The needle is folded the same way -- once per customary spelling
    (fold_ascii's `alternate`) -- and cut into its alphanumeric tokens,
    joined by any run of non-alphanumeric characters, possibly empty: the
    only spellings of `Big Telco` that pass E4 are `big-telco` and
    `bigtelco`, and `O'Brien` becomes `obrien` or `o-brien`. The boundary
    stays the [^\\W_] class of boundary_pattern(), so `bigtelcom` is refused.
    """
    bodies = []
    for alternate in (False, True):
        tokens = re.findall(r"[^\W_]+", fold_ascii(needle, alternate))
        body = r"[\W_]*".join(re.escape(token) for token in tokens)
        if tokens and body not in bodies:
            bodies.append(body)
    if not bodies:
        return _NEVER_RE
    return re.compile(r"(?<![^\W_])(?:" + "|".join(bodies) + r")(?![^\W_])", re.IGNORECASE)


# A needle the folded text pass may take: letters, digits, whitespace and
# the punctuation that only joins the words of a name. `C++`, `AT&T` or `F#`
# fold down to one or two bare letters, which prose is full of: those are
# left to the exact pass alone.
_TEXT_FOLDABLE_RE = re.compile(r"[\w\s'.\-]+")

# What may separate the words of a name in folded text: whitespace, a
# hyphen, an underscore, an apostrophe, a dot, or nothing (`Big-Telco`,
# `BigTelco`, `OBrien`, `jane.doe`). Never a comma or other sentence
# punctuation, so `Big, Telco` stays two words.
_TEXT_FOLD_SEPARATOR = r"[\s_'.\-]*"


# A hyphen that ends a line INSIDE a word (`Big Tel-` / `co`, A5-F2, 05 D-09):
# a hard-wrapped or typeset text splits a long word this way. Allowed between
# any two letters of a token in the folded pass; it spans exactly one `\n`
# (plus the blanks around it), so a match still starts on its own line and
# the line contract e5_haystacks() promises holds.
_WORD_BREAK = r"(?:[-\u2010][ \t]*\n[ \t]*)?"


def _hyphenated(token):
    """TOKEN as a regex that also matches it split by an end-of-line hyphen."""
    return _WORD_BREAK.join(re.escape(ch) for ch in token)


def folded_text_pattern(needle):
    """E5's second text pattern, matched against fold_ascii(text) (WR-03).

    The name as the filename half folds it -- accents dropped, the letters
    NFKD leaves whole transliterated, both spellings of Đ -- with its words
    joined by _TEXT_FOLD_SEPARATOR, so a body typed without accents
    (`Societe Exemple`) or hyphenating the name (`Big-Telco`) is still a
    leak. Matching more is the safe side of a leak check. A needle whose
    punctuation carries meaning (`C++`) gets no folded pattern.
    """
    if _TEXT_FOLDABLE_RE.fullmatch(normalise(needle)) is None:
        return _NEVER_RE
    bodies = []
    for alternate in (False, True):
        tokens = re.findall(r"[^\W_]+", fold_ascii(normalise(needle), alternate))
        body = _TEXT_FOLD_SEPARATOR.join(_hyphenated(token) for token in tokens)
        if tokens and body not in bodies:
            bodies.append(body)
    if not bodies:
        return _NEVER_RE
    return re.compile(r"(?<![^\W_])(?:" + "|".join(bodies) + r")(?![^\W_])", re.IGNORECASE)


# A quoted reply's markers, stripped from the START of every line only
# (multiline mode) before the text is searched: optional leading spaces or
# tabs, then one or more `>` each optionally followed by one space or tab,
# which also strips a nested `> > ` in one pass. No `\n` is ever touched, so
# the line contract e5_haystacks() promises still holds; no configured name
# begins with `>`, so nothing is lost (D-GAP-4, G-02-4f, WR-04 of the
# iteration-3 review).
_QUOTE_STRIP_RE = re.compile(r"^[ \t]*(?:>[ \t]?)+", re.MULTILINE)


def _decode_html_entities(text):
    """TEXT with every HTML character reference decoded, line by line (D-GAP-5).

    `html.unescape()` runs per line and the result is normalise()d again (a
    reference can yield a decomposed accent or U+2019): a numeric reference
    that would otherwise produce a `\\n` (`&#10;`) is turned into a space
    instead, so the line contract e5_haystacks() promises still holds.
    """
    return "\n".join(normalise(html.unescape(line)).replace("\n", " ")
                      for line in text.split("\n"))


# Every Default_Ignorable_Code_Point (Unicode DerivedCoreProperties) -- the
# characters a renderer draws as nothing. Most are category Cf; the ones that
# are not (CGJ, the variation selectors, the Hangul fillers, the Mongolian
# free variation selectors, two Khmer inherent vowels) hid a name from E5 all
# the same (WR-01 of the Phase 2 re-verification, 2026-10-10). Hard-coded: the
# standard library exposes the category, not this property.
_DEFAULT_IGNORABLE_RE = re.compile(
    "[\u00ad\u034f\u061c\u115f\u1160\u17b4\u17b5\u180b-\u180f\u200b-\u200f"
    "\u202a-\u202e\u2060-\u206f\u3164\ufe00-\ufe0f\ufeff\uffa0\ufff0-\ufff8"
    "\U0001bca0-\U0001bca3\U0001d173-\U0001d17a\U000e0000-\U000e0fff]")


def is_invisible(ch):
    """True for a format character (category Cf) or any other default-ignorable code point."""
    return unicodedata.category(ch) == "Cf" or _DEFAULT_IGNORABLE_RE.match(ch) is not None


def format_readings(text):
    """The one or two invisible-blind readings of TEXT (D-GAP-6, CR-02 of the iteration-3 review).

    TEXT itself when it holds no invisible character (is_invisible(): a
    format character of category Cf -- ZWSP, BOM, a soft hyphen, ZWNJ, the
    word joiner, among others -- or any other default-ignorable code point,
    such as a variation selector or CGJ, WR-01 of the re-verification).
    Otherwise two strings, in this order: the deletion reading (every
    invisible character removed -- what one sitting inside a single word
    needs, `Ac<SHY>me` -> `Acme`) and the space reading (every invisible
    character replaced by one space -- what one sitting between two words
    needs, `Big<ZWSP>Telco` -> `Big Telco`). Either reading alone misses a
    real case, so both are always returned together, without duplicates.
    No invisible character is `\\n`, so neither reading adds or removes
    one -- callers that need the line contract e5_haystacks() promises may
    rely on that.
    """
    # Judged once per DISTINCT non-ASCII character (no ASCII character is
    # invisible), then applied with one C-level translate: same result as a
    # per-character test, a fraction of the time on a 5 MB file.
    invisible = [ord(ch) for ch in set(text) if ch > "\x7f" and is_invisible(ch)]
    if not invisible:
        return [text]
    deleted = text.translate({code: None for code in invisible})
    spaced = text.translate({code: " " for code in invisible})
    return [deleted, spaced] if deleted != spaced else [deleted]


# Markup that can sit BETWEEN (or inside) the words of a name (A5-F2, 05 D-09).
# Nothing is parsed or executed: three bounded regular expressions. Every
# repetition is capped, and a `<` that closes no tag within the cap simply
# fails to match, so a hostile file cannot make the scan quadratic.
# - a Markdown link or image target, `](url)` / `](url "title")` / `][ref]`;
# - an HTML tag, comment or declaration (`<b>`, `</p>`, `<wbr>`, `<!-- -->`);
# - the Markdown punctuation that only styles or brackets text: `* ~ ` [ ] \\`
#   (the underscore is left alone, the folded separator already accepts it).
_LINK_TAIL_RE = re.compile(
    r"\]\([^()\s]{0,2000}(?:\s+\"[^\"\n]{0,500}\")?\)|\]\[[^\[\]\n]{0,200}\]")
_TAG_RE = re.compile(r"<[/!?A-Za-z][^<>]{0,2000}>")
_MD_PUNCT_RE = re.compile(r"[*~`\[\]\\]")


def markup_readings(text):
    """The invisible-markup readings of TEXT: [] when it holds none (A5-F2).

    Two strings, like format_readings(): every link target, tag and styling
    mark deleted (what one sitting inside a word needs, `Te<b>lco</b>`), and
    every one replaced by a space (what one between two words needs,
    `<td>Telco</td><td>Corp</td>`). A removed span that held `\\n` keeps them,
    so line k of a reading is line k of TEXT -- the contract e5_haystacks()
    promises. The haystack is searched only; nothing is rewritten on disk.
    """
    if _MD_PUNCT_RE.search(text) is None and "<" not in text:
        return []

    def reading(replacement):
        def blank(match):
            return replacement + "\n" * match.group().count("\n")
        out = _LINK_TAIL_RE.sub(blank, text)
        out = _TAG_RE.sub(blank, out)
        return _MD_PUNCT_RE.sub(replacement, out)

    deleted, spaced = reading(""), reading(" ")
    if deleted == text:
        return []
    return [deleted, spaced] if deleted != spaced else [deleted]


def e5_haystacks(text):
    """The ordered list of line-preserving haystacks E5 searches (D-GAP-4, D-GAP-5, D-GAP-6).

    TEXT is a file's content, already normalise()d with `\\r\\n` and `\\r`
    turned into `\\n`. Every string this returns has exactly as many `\\n`
    as TEXT, and line k of every string comes from line k of TEXT, so a line
    number computed on any of them from its own newline index is the file's
    own line -- check_confidential_names() runs the exact and the folded
    pass on each one, keeping one newline index per string.

    Four stages, each built on the last (the markup one is stage 2b):
    1. A quoted reply's markers are stripped from the start of every line,
       in place -- the stripped text replaces the base rather than joining
       it as a second variant, since a leading `>` never appears inside a
       name (D-GAP-4).
    2. When decoding HTML character references (`&amp;`, `&#39;`, a named or
       numeric reference) changes the already-stripped text, a decoded
       variant is appended (D-GAP-5): `.html` is a sanctioned outbound
       format, but `&amp;`-style text also reaches Markdown and mail drafts
       pasted from a web page, so this applies to every outbound text file,
       not only `.html`. The exact pass is what finds a name holding `&`,
       since folded_text_pattern() deliberately refuses one.
    2b. Link targets, HTML tags and Markdown styling marks are removed from
       the raw and the fully decoded text, once deleted and once as spaces
       (markup_readings(), A5-F2): `**Big** Telco`, `<b>Big</b> Telco`,
       `Big<wbr>Telco` and `[Big](u) [Telco](v)` all read `Big Telco`. HTML
       references are decoded up to three times (`&amp;amp;`).
    3. Every string built so far is replaced, in place, by its
       format_readings() (D-GAP-6): a soft hyphen, ZWSP, BOM, ZWNJ or word
       joiner hides no name whichever way it is read, including one
       decoded from an HTML reference by stage 2 (`&shy;`). Order is kept
       and duplicates are dropped.
    """
    stripped = _QUOTE_STRIP_RE.sub("", text)
    haystacks = [stripped]
    # Decoded again until stable, at most three times: `&amp;amp;` and
    # `&amp;#39;` are double-encoded, and each pass is one more variant.
    current = stripped
    for _ in range(3):
        decoded = _decode_html_entities(current)
        if decoded == current:
            break
        haystacks.append(decoded)
        current = decoded
    # Markup readings of the raw and the fully decoded text only: a tag or a
    # link target between the words of a name hides it from every other
    # stage (A5-F2); `&lt;b&gt;` becomes a tag once decoded.
    for base in ((haystacks[0],) if len(haystacks) == 1 else (haystacks[0], haystacks[-1])):
        for reading in markup_readings(base):
            if reading not in haystacks:
                haystacks.append(reading)
    result = []
    for haystack in haystacks:
        for reading in format_readings(haystack):
            if reading not in result:
                result.append(reading)
    return result


def _build_needle(name):
    """One configured NAME -> (display, exact_patterns, name_pattern, folded_pattern), or
    None when NAME is made only of format characters (D-GAP-6).

    `display` is the last of format_readings() applied to the normalised
    name, whitespace collapsed: the deletion reading when the name holds no
    invisible character, otherwise the space reading -- what every E5 message and
    the (line, name) de-duplication name the leak as. `exact_patterns` is
    boundary_pattern() of every reading, distinct patterns only and
    _NEVER_RE dropped, so the exact pass catches a format character read
    either way (an embedded one needs the deletion reading, one between two
    words needs the space reading). `name_pattern` and `folded_pattern` are
    built from `display` alone: their separator classes already accept an
    empty run between tokens, so the deletion reading is already covered.
    """
    readings = format_readings(normalise(name))
    display = " ".join(readings[-1].split())
    if not display:
        return None
    exact_patterns = []
    seen_patterns = set()
    for reading in readings:
        pattern = boundary_pattern(reading)
        if pattern is _NEVER_RE or pattern.pattern in seen_patterns:
            continue
        seen_patterns.add(pattern.pattern)
        exact_patterns.append(pattern)
    return display, exact_patterns, filename_pattern(display), folded_text_pattern(display)


def percent_decodings(path):
    """PATH as written, then percent-decoded up to three times (A5-F2, 05 D-09).

    A file name saved from a URL carries `%20` for a space, `%C3%A9` for an
    accent, `%2520` when encoded twice; `+` for a space is a separator
    already (the filename pattern accepts any run of non-alphanumerics), so
    it needs no reading of its own. Distinct spellings only, original first.
    Invalid escapes stay as they are (errors="replace" never raises).
    """
    spellings = [path]
    for _ in range(3):
        decoded = urllib.parse.unquote(spellings[-1], errors="replace")
        if decoded == spellings[-1]:
            break
        spellings.append(decoded)
    return spellings


def check_confidential_names(root, tree, config, findings):
    """E5: a confidential name in the text or the filename of an outbound file.

    Suppressed only when consent is recorded AND sourced; a malformed
    consent_recorded reads as False in the schema, so the check stays armed
    (T-02-02). Both sides are NFC-normalised (P-05). The text half searches
    every string e5_haystacks() returns for the file (D-GAP-4, D-GAP-5,
    D-GAP-6), so a name wrapped across two lines, wrapped again inside a
    quoted reply, spelt with an HTML character reference, or carrying a
    Unicode format character is found, and reports the line the match
    starts on, once per (line, name) across every one of those strings.
    Each is searched with every exact pattern _build_needle() built for the
    name, then with folded_text_pattern() on it as fold_ascii() spells it
    (WR-03). Neither stage of e5_haystacks() nor format_readings() adds or
    removes a `\n`, so a line number read off any of them is the same line.
    The filename half matches the slug spellings E4 allows
    (filename_pattern), searched against every format_readings() of the
    path below outbound/ too (D-GAP-6), at most one finding per (file,
    name). A file that will not decode, is symlinked or is oversized skips
    the text half only; the filename half always runs (P-07). The message
    names the needle and the location, never the surrounding sentence
    (T-02-09).

    Hardened by 05 D-09 (A5-F2, A5-F3, A5-F8, Samuel's arbitrage of
    2026-10-11): markup between or inside the words (Markdown emphasis, link
    targets, HTML tags and comments, `<wbr>`), double-encoded HTML
    references, every apostrophe look-alike, a hyphen that breaks a word at
    the end of a line, percent-encoded file names, Cyrillic and Greek
    homoglyphs (_HOMOGLYPHS), and a non-empty `.gitkeep` under outbound/.

    NOT covered, accepted v1 debt (05 D-09): abbreviations and acronyms
    (`BT` for `British Telecom`), nicknames, translations, a name split by
    anything but the separators above, and homoglyphs outside the small
    table. They stay with the doctrine-reviewer alone. E5 is a reminder
    with a fast, honest scope, never a proof that no confidential name
    left the dossier.
    """
    if consent_is_recorded(config) or not config["confidential_names"]:
        return
    needles = [needle for needle in
               (_build_needle(name) for name in config["confidential_names"])
               if needle is not None]
    prefix_len = len(OUTBOUND_DIR) + 1
    # A non-empty `.gitkeep` is a document too (A5-F8): E5 reads it, E1-E4 never see it.
    for rel in outbound_files(tree) + list(tree.gitkeeps):
        # No EXEMPT_PATHS skip here, on purpose: a leaked name is a leak wherever it sits.
        path_readings = []
        for spelling in percent_decodings(rel[prefix_len:]):
            for reading in format_readings(normalise(spelling)):
                folded_reading = fold_ascii(reading)
                if folded_reading not in path_readings:
                    path_readings.append(folded_reading)
        for name, _exact_patterns, name_pattern, _folded_pattern in needles:
            if any(name_pattern.search(path_reading) for path_reading in path_readings):
                findings.append(Finding(rel, 0, ERROR, "E5",
                                        "confidential name '{}' in the file name under outbound/".format(name)))
        text = read_text_safe(os.path.join(root, *rel.split("/")))
        if text is None:
            continue
        norm = normalise(text).replace("\r\n", "\n").replace("\r", "\n")
        seen = set()
        for haystack in e5_haystacks(norm):
            newline_idx = None
            folded_haystack = None
            folded_idx = None
            for name, exact_patterns, _name_pattern, folded_pattern in needles:
                if exact_patterns and newline_idx is None:
                    newline_idx = [m.start() for m in re.finditer("\n", haystack)]
                for regex in exact_patterns:
                    for match in regex.finditer(haystack):
                        number = bisect.bisect_right(newline_idx, match.start()) + 1
                        if (number, name) in seen:
                            continue
                        seen.add((number, name))
                        findings.append(Finding(rel, number, ERROR, "E5",
                                                "confidential name '{}' under outbound/".format(name)))
                if folded_pattern is _NEVER_RE:
                    continue
                if folded_haystack is None:
                    folded_haystack = fold_ascii(haystack)
                    folded_idx = [m.start() for m in re.finditer("\n", folded_haystack)]
                for match in folded_pattern.finditer(folded_haystack):
                    number = bisect.bisect_right(folded_idx, match.start()) + 1
                    if (number, name) in seen:
                        continue
                    seen.add((number, name))
                    findings.append(Finding(rel, number, ERROR, "E5",
                                            "confidential name '{}' under outbound/".format(name)))


def check_consent_source(root, tree, config, findings):
    """E6: consent_recorded true with an empty, absent or null consent_source (D-12, WR-02)."""
    if config["consent_recorded"] and config["consent_source_empty"]:
        findings.append(Finding(CONFIG_NAME, config["consent_line"], ERROR, "E6",
                                "consent_recorded: true with an empty or null consent_source "
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


def check_claude_dirs(root, tree, config, findings):
    """E8: a `.claude/` directory anywhere below the dossier root (D-14).

    Reads the directory list the single walk already produced instead of
    walking again, so pruning is decided in one place: a sub-dossier's own
    `.claude/` never reaches this check from the parent, and linted directly
    it is that root's own folder, which D-14 permits. Reported at line 0,
    with the directory path: the finding is about the folder as a whole.
    """
    for rel in tree.dirs:
        if rel.rsplit("/", 1)[-1] == AGENT_DIR and rel != AGENT_DIR:
            findings.append(Finding(rel, 0, ERROR, "E8",
                                    "{}/ folder below the dossier root".format(AGENT_DIR)))


def check_renders(root, tree, config, findings):
    """E9: a rendered deliverable with no source beside it (D-15).

    Scoped to files directly under outbound/deliverables/. A file whose
    extension is in RENDERED_EXTS needs a sibling with the same stem and an
    extension in RENDER_SOURCE_EXTS. The reverse -- a source with no render
    -- is fine and deliberately silent: a draft is written before it is
    rendered, so do not add the symmetric rule. Reported at line 0.
    """
    prefix = OUTBOUND_DIR + "/deliverables/"
    stems_with_source = set()
    renders = []
    for rel in tree.files:
        if not rel.startswith(prefix) or "/" in rel[len(prefix):]:
            continue
        name = rel[len(prefix):]
        if name == README_NAME:  # D-06, D-10: a README is never a render's source
            continue
        stem, ext = os.path.splitext(name)
        if ext.lower() in RENDER_SOURCE_EXTS:
            stems_with_source.add(stem)
        elif ext.lower() in RENDERED_EXTS:
            renders.append((rel, stem))
    for rel, stem in renders:
        if stem not in stems_with_source:
            findings.append(Finding(rel, 0, ERROR, "E9",
                                    "rendered deliverable without its .md/.html source beside it"))


def language_key(config):
    """The LANGUAGE_WORDS key for this dossier's `language:` value."""
    return config["language"].strip().lower()


def language_words(config):
    """This dossier's word lists, or None when its language has none (D-20)."""
    return LANGUAGE_WORDS.get(language_key(config))


def language_infos(config):
    """The one informational line an unlisted language gets (D-20)."""
    if language_words(config) is not None:
        return []
    return ["language '{}' has no word list: relative-date (W1) and bullet-source (W2) "
            "checks skipped".format(config["language"].strip())]


def check_relative_dates(root, tree, config, findings):
    """W1: a relative-date word in dossier/ or knowledge/ (D-17, spec Sec4.4 check 5).

    Case-insensitive, on normalise()d text, each entry matched with
    boundary_pattern() -- the confidential-name check's boundary. That reuse
    is load-bearing: a substring search fires three times on a clean French
    scaffold, because `hier` is inside `fichier` (P-04). One finding per
    (line, entry); the message names the entry, never the line (T-02-17).
    """
    words = language_words(config)
    if words is None:
        return  # D-20: reported once, by language_infos()
    patterns = [(entry, boundary_pattern(entry)) for entry in words["relative_dates"]]
    prefixes = tuple(folder + "/" for folder in RELATIVE_DATE_DIRS)
    for rel in tree.files:
        if not rel.startswith(prefixes) or os.path.splitext(rel)[1].lower() in BINARY_EXTS:
            continue
        text = read_text_safe(os.path.join(root, *rel.split("/")))
        if text is None:
            continue
        for number, line in enumerate(normalise(text).splitlines(), 1):
            for entry, pattern in patterns:
                if pattern.search(line):
                    # WARNING, never ERROR: a rule that has to guess at natural
                    # language must never be the reason a legitimate draft is
                    # rejected (D-16).
                    findings.append(Finding(rel, number, WARNING, "W1",
                                            "relative-date word '{}': write the absolute date".format(entry)))


def visible_lines(text):
    """(line number, the line with HTML comments removed), for every line.

    A depth counter survives across lines, so a bullet inside a multi-line
    `<!--` ... `-->` block is invisible (P-03). Do not lean on the accident
    that every shipped example line is a whole-line comment: a human writing
    the block form is what this tracker exists for. An opener inside an open
    comment deepens it and a stray closer never drives the depth negative,
    so a malformed file degrades to "more is hidden", never to a crash.
    """
    depth = 0
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
        yield number, "".join(out)


def check_bullet_sources(root, tree, config, findings):
    """W2: a bullet in a living file with no parenthetical source (D-18).

    Iterates the explicit LIVING_FILES tuple, never the folder:
    dossier/README.md ships seven unsourced bullets and is not a living file
    (P-02). A bullet is legitimate when it ends with a parenthetical source
    or carries one of the language's opinion markers, matched with
    boundary_pattern() so an inflected form is not a marker (spec Sec3.4).
    Comment text is invisible; a heading is never a bullet. The message
    carries the location only, never the line (T-02-17).
    """
    words = language_words(config)
    if words is None:
        return  # D-20: reported once, by language_infos()
    markers = [boundary_pattern(marker) for marker in words["opinion_markers"]]
    for name in LIVING_FILES:
        rel = LIVING_DIR + "/" + name
        if rel not in tree.file_set:
            continue  # E7 already reports it
        text = read_text_safe(os.path.join(root, LIVING_DIR, name))
        if text is None:
            continue  # E7 already reports it
        for number, line in visible_lines(normalise(text)):
            body = line.strip()
            if not body.startswith(_BULLET_PREFIXES):
                continue
            if _PAREN_SOURCE_RE.search(body) or any(marker.search(body) for marker in markers):
                continue
            # WARNING, never ERROR: a rule that has to guess at natural
            # language must never be the reason a legitimate draft is
            # rejected (D-16).
            findings.append(Finding(rel, number, WARNING, "W2",
                                    "bullet line without a parenthetical source or an opinion marker"))


CHECKS = (
    check_outbound_headers,
    check_outbound_names,
    check_confidential_names,
    check_consent_source,
    check_living_files,
    check_claude_dirs,
    check_renders,
    check_relative_dates,
    check_bullet_sources,
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
    infos = language_infos(config) + [
        "sub-dossier {}/ skipped: it holds its own {} (lint it separately)".format(rel, CONFIG_NAME)
        for rel in tree.pruned] + [
        "folder {}/ is a symlink, not followed: its files are not checked".format(rel)
        for rel in tree.symlinks if not _in_outbound(rel)] + [
        "folder {}/ cannot be read: its files are not checked".format(rel)
        for rel in tree.unreadable if not _in_outbound(rel)] + [
        "folder {}/ is a .git folder, never walked: its files are not checked".format(rel)
        for rel in tree.git_dirs if not _in_outbound(rel)]
    errors, _warnings = report(findings, infos)
    return EXIT_ERRORS if errors else EXIT_CLEAN


def _tolerant_streams():
    """Escape, never raise on, a character the console cannot encode (WR-06).

    A finding carries confidential names and word-list entries; on a
    non-UTF-8 stdout (a Windows console or pipe, a legacy locale) a strict
    encoder would turn that finding into an internal failure (exit 3) and
    lose it. reconfigure() exists from Python 3.7; a replaced stream
    without it is left alone.
    """
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(errors="backslashreplace")
        except (AttributeError, ValueError):
            pass


def main(argv=None):
    _tolerant_streams()
    args = build_parser().parse_args(argv)
    try:
        return _run(args.path)
    except Exception as exc:  # P-08: never masquerade as "this dossier has errors"
        print("error: internal linter failure: {}: {}".format(type(exc).__name__, exc), file=sys.stderr)
        return EXIT_INTERNAL


if __name__ == "__main__":
    sys.exit(main())
