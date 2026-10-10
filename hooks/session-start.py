#!/usr/bin/env python3
"""SessionStart reminder for a client dossier.

Mechanics tier only (spec principle: "hooks carry reminders"). Claude Code
runs this script when a session starts, resumes, is cleared or is compacted,
and feeds it one JSON object on stdin. When a dossier.yaml is found upward
from the session cwd (the root or any subfolder), the script prints one JSON
object whose additionalContext tells the agent that the repository is a client
dossier, names the nearest root and asks it to load the `dossier` skill
(PROTO-04). Without a dossier.yaml it prints nothing at all.

The root is searched upward from the session cwd with the very same find_root
as scripts/lint.py (PROTO-08), so a nested dossier resolves to the nearest one.

There is no matcher-specific logic: every `source` (startup, resume, clear,
compact, fork) gets the same text, so the reminder survives a compaction.

The text is fixed. The script never opens dossier.yaml, so no confidential name
configured there can reach the model through this reminder (T-03-15). It is
read-only and fails open: any error or malformed stdin gives exit 0 with no
output, so a broken hook never disturbs the many sessions where the plugin is
enabled and no dossier is around.

Python 3 standard library only, targeting Python >= 3.8.
"""

import json
import os
import sys
from pathlib import Path

CONFIG_NAME = "dossier.yaml"


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


def reminder(root):
    """The two-line reminder naming the dossier root."""
    return "\n".join((
        "This repository is a client dossier (dossier.yaml at %s)." % root,
        "Load the `dossier` skill (client-dossier:dossier) before acting.",
    ))


def main():
    data = json.load(sys.stdin)
    if not isinstance(data, dict):
        return
    cwd = data.get("cwd")
    if not isinstance(cwd, str) or not cwd:
        cwd = os.getcwd()
    root = find_root(cwd)
    if root is None:
        return
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": reminder(root),
    }}))


if __name__ == "__main__":
    try:
        main()
    except Exception:  # fail open: a broken reminder must never disturb a session
        pass
    sys.exit(0)
