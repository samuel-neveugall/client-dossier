#!/usr/bin/env python3
"""Stop check: update the dossier before handing back, asked once.

Mechanics tier only (spec principle: "hooks carry reminders"). Claude Code
runs this script when the agent is about to stop and feeds it one JSON object
on stdin. When `git status` of the nearest dossier shows uncommitted changes
under outbound/ or sources/ and none under dossier/, the script prints one
block decision whose reason is addressed to the agent: update the living files
the work touched, or say in one sentence why none needed it (PROTO-06, D-01).

It blocks AT MOST ONCE per turn: when the stdin carries `stop_hook_active`
true (the stop that follows the block), it prints nothing, so it can never
loop. Claude Code's own continuation cap is not relied upon.

The trigger is stateless (D-02): no per-session baseline, only the working
tree against the index and HEAD. Not a git repository, `git` missing from
PATH, no dossier.yaml upward, a fresh uncommitted scaffold, a wholly untracked
dossier folder, a sibling dossier's changes, or changes that include dossier/
all leave it silent. git prints paths relative to the repository top level, so
the prefix of the dossier inside the repository (`rev-parse --show-prefix`) is
stripped first; renames and copies are classified on both sides.

The dossier root is searched upward from the session cwd with the very same
find_root as scripts/lint.py (PROTO-08), so a nested dossier resolves to the
nearest one. The script is read-only (`git --no-optional-locks`, no shell, an
argument list, `--` before the pathspec, NUL separated output) and fails open:
any error, timeout or malformed stdin gives exit 0 with no output at all.

Python 3 standard library only, targeting Python >= 3.8.
"""

import json
import os
import subprocess
import sys
from pathlib import Path

CONFIG_NAME = "dossier.yaml"
LIVING_DIR = "dossier"
OUTBOUND_DIR = "outbound"
SOURCES_DIR = "sources"
GIT_TIMEOUT = 10


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


def git_output(root, args):
    """The stdout bytes of `git -C root ARGS`, or None when git cannot answer.

    None covers a non-zero exit (not a repository), git missing from PATH, any
    other OS error and a timeout: D-02 makes every one of them silent.
    """
    try:
        result = subprocess.run(
            ["git", "--no-optional-locks", "-C", root] + args,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=GIT_TIMEOUT,
        )
    except (FileNotFoundError, OSError, subprocess.TimeoutExpired):
        return None
    if result.returncode != 0:
        return None
    return result.stdout


def decode(raw):
    """A path from git, UTF-8 with undecodable bytes kept (surrogateescape)."""
    return raw.decode("utf-8", "surrogateescape")


def changed_top_dirs(root):
    """The casefolded first path component, relative to the dossier root, of
    every uncommitted change in it; None when git failed (D-02: silent).

    An entry is two status letters, a space and a path. A rename or a copy
    (`R` or `C` in either letter) is followed by one more NUL field, the
    original path, which is classified too. A path outside the dossier, or the
    dossier folder itself (a wholly untracked dossier collapses to one entry),
    adds nothing.
    """
    prefix_raw = git_output(root, ["rev-parse", "--show-prefix"])
    if prefix_raw is None:
        return None
    prefix = decode(prefix_raw).rstrip("\n")
    status = git_output(
        root,
        ["status", "--porcelain=v1", "-z", "--untracked-files=normal", "--", "."],
    )
    if status is None:
        return None
    fields = status.split(b"\0")
    paths = []
    index = 0
    while index < len(fields):
        entry = fields[index]
        index += 1
        if len(entry) < 4:
            continue
        letters = decode(entry[:2])
        paths.append(decode(entry[3:]))
        if "R" in letters or "C" in letters:
            if index < len(fields):
                paths.append(decode(fields[index]))
            index += 1
    tops = set()
    for path in paths:
        if not path.startswith(prefix):
            continue
        rest = path[len(prefix):]
        top = rest.split("/")[0].casefold()
        if top:
            tops.add(top)
    return tops


# PROVISIONAL (P-02, 03-CONTEXT.md "Pending decisions", awaiting Samuel).
# status_sentence() makes the Stop reason name the dossier-status skill only
# when that skill is installed beside this hook, that is when
# ${CLAUDE_PLUGIN_ROOT}/skills/dossier-status/SKILL.md is a file. Why: D-01
# wants the reason to name dossier-status as the way to check what is stale,
# while D-07 forbids pointing the agent at a skill that does not exist yet (it
# lands in Phase 6); done this way the hook starts naming it the day Phase 6
# ships the skill, with no edit here. An empty or unset CLAUDE_PLUGIN_ROOT
# never falls back to a relative path. Reversion path: "always name it" =
# return the sentence unconditionally; "never name it" = return an empty
# string; in both cases update the two P-02 assertions in
# tests/test-hook-stop.sh. Nothing else in the hooks mentions dossier-status.
def status_sentence():
    """The sentence naming dossier-status (leading space), or an empty string."""
    plugin_root = os.environ.get("CLAUDE_PLUGIN_ROOT")
    if not plugin_root:
        return ""
    skill = os.path.join(plugin_root, "skills", "dossier-status", "SKILL.md")
    if os.path.isfile(skill):
        return " Run the dossier-status skill to check what is stale."
    return ""


def block_reason(touched):
    """The reason handed to the agent; `touched` names the changed folders."""
    return (
        "%s changed in this dossier but nothing under dossier/ did. "
        "Before handing back, update the living files the work touched "
        "(one dated, sourced line per fact), or say in one sentence why "
        "none needed it." % touched
    ) + status_sentence()


def main():
    data = json.load(sys.stdin)
    if not isinstance(data, dict):
        return
    if data.get("stop_hook_active"):
        return  # D-01: the second stop of the turn passes, never a loop
    cwd = data.get("cwd")
    if not isinstance(cwd, str) or not cwd:
        cwd = os.getcwd()
    root = find_root(cwd)
    if root is None:
        return
    tops = changed_top_dirs(root)
    if not tops or LIVING_DIR in tops:
        return
    outbound = OUTBOUND_DIR in tops
    sources = SOURCES_DIR in tops
    if outbound and sources:
        touched = "outbound/ and sources/"
    elif outbound:
        touched = "outbound/"
    elif sources:
        touched = "sources/"
    else:
        return
    print(json.dumps({"decision": "block", "reason": block_reason(touched)}))


if __name__ == "__main__":
    try:
        main()
    except Exception:  # fail open: a broken check must never trap the agent
        pass
    sys.exit(0)
