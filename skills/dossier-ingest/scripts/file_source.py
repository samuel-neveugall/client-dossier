#!/usr/bin/env python3
"""File one source into a client-dossier repository's sources/ folder.

Mechanics tier only (spec principle: "skills carry the judgement, scripts
carry the mechanics"). Every input arrives as a command-line argument: this
script never prompts, never reads a TTY and starts no other process. Judgement
(which kind a source is, which content date and slug it gets, whether a
downloaded page is a login page) lives in skills/dossier-ingest/SKILL.md.

It is the only route a source takes into sources/: the Write and Edit tools
are denied there by hooks/guard-sources.py, so filing is this script's job.

Usage:
    file_source.py --kind received|transcript|raw [--date YYYY-MM-DD]
                   [--slug TEXT] PATH

Every path prints exactly one ASCII-only JSON object on stdout and exits
0 (filed), 1 (refused or failed), 2 (no dossier.yaml upward, as lint.py) or
3 (internal error).

Python 3 standard library only, targeting Python >= 3.8.
"""

import argparse
import datetime
import hashlib
import json
import os
import shutil
import sys
import tempfile
import unicodedata
from pathlib import Path

CONFIG_NAME = "dossier.yaml"
GITKEEP = ".gitkeep"

EXIT_OK = 0
EXIT_REFUSED = 1
EXIT_NO_DOSSIER = 2
EXIT_INTERNAL = 3

# D-07: the folder follows the kind the skill decided.
KIND_DIRS = {
    "received": "sources/received",
    "transcript": "sources/transcripts",
    "raw": "sources/transcripts/raw",
}

CHUNK = 1 << 16
SLUG_MAX = 60
EXT_MAX = 10
_DIGITS = "0123456789"
_SLUG_CHARS = "abcdefghijklmnopqrstuvwxyz" + _DIGITS


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


class Refusal(Exception):
    """A refused or failed run, reported as a JSON error and an exit code."""

    def __init__(self, code, message, hint=None, status=EXIT_REFUSED):
        Exception.__init__(self, message)
        self.code = code
        self.message = message
        self.hint = hint
        self.status = status

    def result(self):
        out = {"status": "error", "error": self.code, "message": self.message}
        if self.hint:
            out["hint"] = self.hint
        return out


class _Parser(argparse.ArgumentParser):
    """A parser whose usage errors are JSON, not a stderr dump and exit 2."""

    def error(self, message):
        raise Refusal("usage", message)


def build_parser():
    parser = _Parser(
        description="File one source into sources/ (mechanics tier; never interactive).",
        add_help=False,
        allow_abbrev=False,
    )
    parser.add_argument("--kind", required=True, choices=sorted(KIND_DIRS))
    parser.add_argument("--date", default=None)
    parser.add_argument("--slug", default=None)
    parser.add_argument("path")
    return parser


def slugify(text):
    """Fold TEXT to the [a-z0-9]+(-[a-z0-9]+)* shape lint requires of names."""
    folded = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode("ascii")
    out = []
    dash = False
    for ch in folded.lower():
        if ch in _SLUG_CHARS:
            out.append(ch)
            dash = False
        elif not dash and out:
            out.append("-")
            dash = True
    return "".join(out).strip("-")[:SLUG_MAX].strip("-") or "source"


def extension_of(name):
    """The lowercased extension when it is a dot and 1 to 10 of a-z0-9."""
    ext = os.path.splitext(name)[1].lower()
    body = ext[1:]
    if body and len(body) <= EXT_MAX and all(ch in _SLUG_CHARS for ch in body):
        return ext
    return ""


def resolve_date(text):
    """D-01: --date, else the local filing date. Exactly YYYY-MM-DD, a real day."""
    if text is None:
        return datetime.date.today().isoformat()
    shaped = (
        len(text) == 10
        and text[4] == "-"
        and text[7] == "-"
        and all(ch in _DIGITS for ch in text[:4] + text[5:7] + text[8:])
    )
    if shaped:
        try:
            datetime.date(int(text[:4]), int(text[5:7]), int(text[8:]))
            return text
        except ValueError:
            pass
    raise Refusal(
        "bad_date",
        "--date must be a real calendar date written YYYY-MM-DD",
    )


def sha256_of(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        while True:
            chunk = handle.read(CHUNK)
            if not chunk:
                return digest.hexdigest()
            digest.update(chunk)


def run_file(argv):
    args = build_parser().parse_args(argv)
    date = resolve_date(args.date)
    root = find_root(os.getcwd())
    if root is None:
        raise Refusal(
            "no_dossier",
            "no dossier.yaml in the current directory or above it",
            status=EXIT_NO_DOSSIER,
        )
    incoming = os.path.realpath(args.path)
    given = os.path.basename(args.path.rstrip("/")) or args.path
    slug = slugify(args.slug if args.slug is not None else os.path.splitext(given)[0])
    name = "{}_{}{}".format(date, slug, extension_of(given))

    stage = tempfile.mkdtemp(prefix="client-dossier-file-")
    try:
        staged = os.path.join(stage, "incoming")
        with open(incoming, "rb") as fin, open(staged, "xb") as fout:
            shutil.copyfileobj(fin, fout, CHUNK)
        digest = sha256_of(staged)
        size = os.path.getsize(staged)

        folder = os.path.join(root, KIND_DIRS[args.kind])
        os.makedirs(folder, exist_ok=True)
        target = os.path.join(folder, name)
        with open(staged, "rb") as fin, open(target, "xb") as fout:
            shutil.copyfileobj(fin, fout, CHUNK)
    finally:
        shutil.rmtree(stage, ignore_errors=True)

    rel = KIND_DIRS[args.kind] + "/" + name
    return (
        {"status": "filed", "path": rel, "sha256": digest, "bytes": size, "warnings": []},
        EXIT_OK,
    )


def emit(result):
    sys.stdout.write(json.dumps(result, ensure_ascii=True) + "\n")
    sys.stdout.flush()


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    try:
        result, code = run_file(argv)
    except Refusal as refusal:
        result, code = refusal.result(), refusal.status
    except Exception as exc:  # never a traceback: the agent reads one JSON object
        result = {
            "status": "error",
            "error": "internal",
            "message": "{}: {}".format(type(exc).__name__, exc),
        }
        code = EXIT_INTERNAL
    emit(result)
    return code


if __name__ == "__main__":
    sys.exit(main())
