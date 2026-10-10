#!/usr/bin/env python3
"""PreToolUse guard on a dossier's sources/ folder.

Mechanics tier only (spec principle: "hooks carry reminders"). Claude Code
runs this script before Write, Edit, MultiEdit, NotebookEdit and Bash calls
and feeds it one JSON object on stdin. When the target resolves under the
`sources/` folder of the nearest dossier, the script prints one deny decision
carrying the spec sentence "sources are immutable; file a correction in the
dossier instead" (PROTO-05). Every write under sources/ is denied, new files
included (D-03). A Bash command that visibly modifies an existing file there
is denied too, by a heuristic that is not the boundary: the skill's rule is
(D-04).

The dossier root is searched upward from the TARGET path, not from the
session cwd, with the very same find_root as scripts/lint.py (PROTO-08), so a
session started above a nested dossier still protects that dossier's sources/
and the nearest dossier wins.

It is read-only and fails open: any error, malformed stdin or missing field
gives exit 0 with no output at all, so a broken guard never blocks a write in
the many repositories where the plugin is enabled. It never prints an allow
decision (that would bypass the user's own permission rules); a silent run
leaves Claude Code's normal permission flow in charge.

Python 3 standard library only, targeting Python >= 3.8.
"""

import json
import os
import sys
from pathlib import Path

CONFIG_NAME = "dossier.yaml"
SOURCES_DIR = "sources"
MESSAGE = "sources are immutable; file a correction in the dossier instead"

WRITE_TOOLS = ("Write", "Edit", "MultiEdit", "NotebookEdit")


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


def sources_target(path, cwd):
    """The path of `path` relative to its dossier root when it lies under
    that dossier's sources/ folder, else None.

    The path is joined to `cwd` (an absolute path stays absolute) and
    resolved through symlinks and `..`; the root is searched from the target
    so the nearest dossier wins; the first component is compared casefolded
    because a case-insensitive filesystem keeps the spelling that was typed.
    """
    target = os.path.realpath(os.path.join(cwd, path))
    root = find_root(os.path.dirname(target))
    if root is None:
        return None
    rel = os.path.relpath(target, root)
    parts = rel.split(os.sep)
    if parts[0] in (".", "..") or parts[0].casefold() != SOURCES_DIR:
        return None
    return "/".join(parts)


def bash_hit(command, cwd):
    """The root-relative path of an existing source file that `command`
    appears to modify, else None. Filled in by the heuristic Bash guard."""
    return None


def main():
    data = json.load(sys.stdin)
    if not isinstance(data, dict):
        return
    cwd = data.get("cwd") or os.getcwd()
    tool = data.get("tool_name")
    tool_input = data.get("tool_input") or {}
    if not isinstance(tool_input, dict):
        return
    hit = None
    note = ""
    if tool in WRITE_TOOLS:
        path = tool_input.get("file_path") or tool_input.get("notebook_path")
        if isinstance(path, str) and path:
            hit = sources_target(path, cwd)
    elif tool == "Bash":
        command = tool_input.get("command")
        if isinstance(command, str) and command:
            hit = bash_hit(command, cwd)
            note = " (heuristic guard: this Bash command appears to modify it)"
    if hit:
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": MESSAGE + ": " + hit + note,
        }}))


if __name__ == "__main__":
    try:
        main()
    except Exception:  # fail open: a broken guard must never block a write
        pass
    sys.exit(0)
