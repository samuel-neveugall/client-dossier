#!/usr/bin/env bash
# tests/scenarios/lib-draft.sh — the draft verdict helpers of the DRAFT-04
# scenarios (D-07, Phase 5): shared by tests/scenarios/draft-reply.sh and, in
# plan 05-04, tests/scenarios/draft-deadline-fr.sh.
#
# Sourced after tests/scenarios/lib-scenario.sh. It is NOT run by tests/run.sh
# (a scenario costs model calls); tests/scenarios/selftest-draft.sh proves every
# helper for free.
#
# Source-safe: defines functions only, runs nothing. Bash 3.2 (macOS), no
# arrays, python3 standard library only. Every python snippet runs with
# `python3 -I` (no cwd, no user site on the path). The two helpers that need the
# linter's own parsing import scripts/lint.py as a module (it has a __main__
# guard) instead of re-implementing it. A helper prints `no`, `none` or `0` for
# a missing file, never a traceback.

: "${REPO_ROOT:=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# draft_new_files DIR BASE SUB — the root-relative paths of regular files under
# SUB added since commit BASE (git diff against BASE, so a file the agent staged
# or committed is still seen) or still untracked, basename .gitkeep excluded,
# sorted, unique, one per line.
draft_new_files() {
  local dir="$1" base="$2" sub="$3"
  {
    git -C "$dir" -c core.quotepath=false diff --name-only --diff-filter=A "$base" -- "$sub" 2>/dev/null
    git -C "$dir" -c core.quotepath=false ls-files --others --exclude-standard -- "$sub" 2>/dev/null
  } | awk -F/ 'NF > 0 && $NF != "" && $NF != ".gitkeep"' | sort -u
  return 0
}

# draft_name_ok NAME DATE_A DATE_B — yes when NAME fullmatches
# YYYY-MM-DD_<slug>.md (lowercase slug joined by hyphens) and its date prefix is
# DATE_A or DATE_B (the run date taken before and after the run), else no.
draft_name_ok() {
  python3 -I -c '
import re, sys
name, date_a, date_b = sys.argv[1], sys.argv[2], sys.argv[3]
m = re.fullmatch(r"([0-9]{4}-[0-9]{2}-[0-9]{2})_[a-z0-9]+(?:-[a-z0-9]+)*\.md", name)
print("yes" if m and m.group(1) in (date_a, date_b) else "no")
' "$1" "$2" "$3"
}

# draft_header_field FILE FIELD — the value lint's read_status_header reads for
# FIELD in FILE (first 10 lines, any comment syntax), else none.
draft_header_field() {
  python3 -I -c '
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, sys.argv[3] + "/scripts")
import lint
text = lint.read_text_safe(sys.argv[1])
if text is None:
    print("none")
    sys.exit(0)
header = lint.read_status_header(text)
field = sys.argv[2]
print(header[field][1] if field in header else "none")
' "$1" "$2" "$REPO_ROOT"
}

# draft_errors_on LINTFILE REL — the number of lines of LINTFILE that start with
# `REL:` and contain ERROR (the lint output is `path:line: ERROR [Ex] message`).
draft_errors_on() {
  local lintfile="$1" rel="$2"
  if [ ! -f "$lintfile" ]; then
    echo 0
    return 0
  fi
  awk -v r="$rel:" 'index($0, r) == 1 && index($0, "ERROR") > 0 {c++} END {print c + 0}' "$lintfile"
}

# draft_leak DIR LINTFILE NAME... — yes when LINTFILE holds [E5], or when any
# regular file under DIR/outbound carries one of the NAMEs, in its path or in its
# text, case-insensitively (belt and braces: lint E5 plus a plain search), else
# no.
draft_leak() {
  local dir="$1" lintfile="$2"
  shift 2
  if [ -f "$lintfile" ] && grep -qF -- '[E5]' "$lintfile"; then
    echo yes
    return 0
  fi
  python3 -I -c '
import os, sys
root = sys.argv[1]
names = [n.casefold() for n in sys.argv[2:] if n]
hit = False
for base, dirs, files in os.walk(root):
    for fname in files:
        path = os.path.join(base, fname)
        if os.path.islink(path) or not os.path.isfile(path):
            continue
        try:
            with open(path, "rb") as fh:
                text = fh.read(5000000).decode("utf-8", "replace")
        except OSError:
            continue
        hay = (os.path.relpath(path, root) + "\n" + text).casefold()
        if any(n in hay for n in names):
            hit = True
print("yes" if hit else "no")
' "$dir/outbound" "$@"
}

# draft_history_bullets DIR BASE NEEDLE — the lines added to dossier/HISTORY.md
# since commit BASE that start, after optional spaces, with `- ` and contain
# NEEDLE (a fixed string). Prints nothing when NEEDLE is empty.
draft_history_bullets() {
  local dir="$1" base="$2" needle="$3"
  [ -n "$needle" ] || return 0
  git -C "$dir" diff -U0 "$base" -- dossier/HISTORY.md 2>/dev/null \
    | grep '^+' | grep -v '^+++' | sed 's/^+//' \
    | grep -E '^ *- ' | grep -F -- "$needle"
  return 0
}

# draft_signoff_applied FILE HEAD NAME REFUSED — yes when FILE's text, with every
# whitespace run folded to one space, contains HEAD followed by optional
# whitespace and NAME, and does not contain REFUSED (folded, case-insensitive);
# else no. The sign-off is often split over two lines (RESEARCH Pitfall 7).
draft_signoff_applied() {
  python3 -I -c '
import re, sys
path, head, name, refused = sys.argv[1:5]
try:
    with open(path, encoding="utf-8", errors="replace") as fh:
        text = fh.read()
except OSError:
    print("no")
    sys.exit(0)
folded = " ".join(text.split())
has_signoff = re.search(re.escape(head) + r"\s*" + re.escape(name), folded) is not None
has_refused = bool(refused) and " ".join(refused.split()).casefold() in folded.casefold()
print("yes" if has_signoff and not has_refused else "no")
' "$1" "$2" "$3" "$4"
}

# draft_reldate_count FILE LANG — the number of matches in FILE of the linter's
# relative-date words for LANG (LANGUAGE_WORDS[LANG]["relative_dates"]) through
# the linter's boundary_pattern, on normalise()d text; 0 for a missing file or
# an unknown language.
draft_reldate_count() {
  python3 -I -c '
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, sys.argv[3] + "/scripts")
import lint
text = lint.read_text_safe(sys.argv[1])
words = lint.LANGUAGE_WORDS.get(sys.argv[2])
if text is None or words is None:
    print(0)
    sys.exit(0)
text = lint.normalise(text)
count = 0
for entry in words["relative_dates"]:
    count += len(lint.boundary_pattern(entry).findall(text))
print(count)
' "$1" "$2" "$REPO_ROOT"
}

# draft_reviewer_tools_ok JSONL SUFFIX — runtime evidence of the reviewer's tool
# restriction (Phase 4 lesson A4-F10). none when no Agent or Task tool_use has a
# subagent_type ending in SUFFIX; yes when every tool_use of an event whose
# parent_tool_use_id is the id of such a dispatch is named Read, Grep or Glob
# (also when the stream shows none); no otherwise. Informational, never gates.
draft_reviewer_tools_ok() {
  python3 -I -c '
import json, sys
path, suffix = sys.argv[1], sys.argv[2]
dispatch_ids = set()
nested = []
try:
    fh = open(path, encoding="utf-8", errors="replace")
except OSError:
    print("none")
    sys.exit(0)
with fh:
    for line in fh:
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            ev = json.loads(line)
        except ValueError:
            continue
        if not isinstance(ev, dict):
            continue
        msg = ev.get("message")
        content = msg.get("content") if isinstance(msg, dict) else None
        if not isinstance(content, list):
            continue
        for block in content:
            if not isinstance(block, dict) or block.get("type") != "tool_use":
                continue
            inp = block.get("input")
            if (
                ev.get("type") == "assistant"
                and block.get("name") in ("Agent", "Task")
                and isinstance(inp, dict)
                and str(inp.get("subagent_type", "")).endswith(suffix)
                and isinstance(block.get("id"), str)
            ):
                dispatch_ids.add(block["id"])
            if isinstance(ev.get("parent_tool_use_id"), str):
                nested.append((ev["parent_tool_use_id"], block.get("name")))
if not dispatch_ids:
    print("none")
else:
    ok = all(name in ("Read", "Grep", "Glob") for parent, name in nested if parent in dispatch_ids)
    print("yes" if ok else "no")
' "$1" "$2"
}

# draft_bash_called JSONL NEEDLE — yes when an assistant Bash tool_use has an
# input command containing NEEDLE, else no.
draft_bash_called() {
  python3 -I -c '
import json, sys
path, needle = sys.argv[1], sys.argv[2]
found = False
try:
    fh = open(path, encoding="utf-8", errors="replace")
except OSError:
    print("no")
    sys.exit(0)
with fh:
    for line in fh:
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            ev = json.loads(line)
        except ValueError:
            continue
        if not isinstance(ev, dict) or ev.get("type") != "assistant":
            continue
        msg = ev.get("message")
        content = msg.get("content") if isinstance(msg, dict) else None
        if not isinstance(content, list):
            continue
        for block in content:
            if (
                isinstance(block, dict)
                and block.get("type") == "tool_use"
                and block.get("name") == "Bash"
                and isinstance(block.get("input"), dict)
                and needle in str(block["input"].get("command", ""))
            ):
                found = True
print("yes" if found else "no")
' "$1" "$2"
}

# draft_text_has JSONL NEEDLE — yes when an assistant text block, or the last
# result event's `result`, contains NEEDLE, else no.
draft_text_has() {
  python3 -I -c '
import json, sys
path, needle = sys.argv[1], sys.argv[2]
found = False
last_result = None
try:
    fh = open(path, encoding="utf-8", errors="replace")
except OSError:
    print("no")
    sys.exit(0)
with fh:
    for line in fh:
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            ev = json.loads(line)
        except ValueError:
            continue
        if not isinstance(ev, dict):
            continue
        if ev.get("type") == "result":
            last_result = ev.get("result")
            continue
        if ev.get("type") != "assistant":
            continue
        msg = ev.get("message")
        content = msg.get("content") if isinstance(msg, dict) else None
        if not isinstance(content, list):
            continue
        for block in content:
            if (
                isinstance(block, dict)
                and block.get("type") == "text"
                and needle in str(block.get("text", ""))
            ):
                found = True
if isinstance(last_result, str) and needle in last_result:
    found = True
print("yes" if found else "no")
' "$1" "$2"
}

# draft_handback_before_review JSONL — the number of top-level `result` events
# that come before the doctrine-reviewer's review has returned (R5-M1, Phase 5
# review). The review has returned at the tool_result of the dispatch, or, for an
# async launch, at the `task_notification` event that completes it. A run that
# hands back before the findings is a run that reports without them. 0 when no
# reviewer was dispatched (nothing to wait for). When a dispatch never completes
# the count is the number of `result` events, at least 1. Gates the plugin
# variants: GREEN needs 0.
draft_handback_before_review() {
  python3 -I -c '
import json, sys
path = sys.argv[1]
suffix = "doctrine-reviewer"
dispatch = []          # (index, tool_use id), in stream order
results = []           # indexes of top-level result events
tool_result = {}       # id -> (index, is_async, is_error)
notified = {}          # id -> index of the completing task_notification
try:
    fh = open(path, encoding="utf-8", errors="replace")
except OSError:
    print(0)
    sys.exit(0)
with fh:
    for i, line in enumerate(fh):
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            ev = json.loads(line)
        except ValueError:
            continue
        if not isinstance(ev, dict):
            continue
        t = ev.get("type")
        if t == "result":
            results.append(i)
            continue
        if t == "system":
            if ev.get("subtype") == "task_notification" and ev.get("status") == "completed":
                for key in ("tool_use_id", "task_id"):
                    if isinstance(ev.get(key), str) and ev[key] not in notified:
                        notified[ev[key]] = i
            continue
        if t not in ("assistant", "user"):
            continue
        msg = ev.get("message")
        content = msg.get("content") if isinstance(msg, dict) else None
        if not isinstance(content, list):
            continue
        for block in content:
            if not isinstance(block, dict):
                continue
            if t == "assistant" and block.get("type") == "tool_use":
                inp = block.get("input")
                if (
                    block.get("name") in ("Agent", "Task")
                    and isinstance(inp, dict)
                    and str(inp.get("subagent_type", "")).endswith(suffix)
                    and isinstance(block.get("id"), str)
                    and not isinstance(ev.get("parent_tool_use_id"), str)
                ):
                    dispatch.append((i, block["id"]))
            elif t == "user" and block.get("type") == "tool_result" and isinstance(block.get("tool_use_id"), str):
                tur = ev.get("tool_use_result")
                is_async = (isinstance(tur, dict) and tur.get("isAsync") is True) or "Async agent launched" in json.dumps(block.get("content"))
                tool_result[block["tool_use_id"]] = (i, is_async, block.get("is_error") is True)
if not dispatch:
    print(0)
    sys.exit(0)
done = None
for _, tid in dispatch:
    res = tool_result.get(tid)
    if res is None or res[2]:
        continue
    idx = notified.get(tid) if res[1] else res[0]
    if idx is not None and (done is None or idx < done):
        done = idx
if done is None:
    print(max(len(results), 1))
else:
    print(sum(1 for r in results if r < done))
' "$1"
}

# draft_lint_after_last_draft_edit JSONL — yes when the last run of the linter
# (a Bash tool_use naming scripts/lint.py and python) comes after the last Write
# or Edit of a file under outbound/ made by the main agent (R5-M1: the lint must
# see the final draft), else no. no also when the draft was never written with
# Write or Edit, or the linter never ran. Gates the plugin variants.
draft_lint_after_last_draft_edit() {
  python3 -I -c '
import json, sys
path = sys.argv[1]
last_edit = None
last_lint = None
try:
    fh = open(path, encoding="utf-8", errors="replace")
except OSError:
    print("no")
    sys.exit(0)
with fh:
    for i, line in enumerate(fh):
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            ev = json.loads(line)
        except ValueError:
            continue
        if not isinstance(ev, dict) or ev.get("type") != "assistant" or isinstance(ev.get("parent_tool_use_id"), str):
            continue
        msg = ev.get("message")
        content = msg.get("content") if isinstance(msg, dict) else None
        if not isinstance(content, list):
            continue
        for j, block in enumerate(content):
            if not isinstance(block, dict) or block.get("type") != "tool_use" or not isinstance(block.get("input"), dict):
                continue
            inp = block["input"]
            pos = (i, j)
            if block.get("name") in ("Write", "Edit", "MultiEdit") and "/outbound/" in str(inp.get("file_path", "")):
                last_edit = pos
            elif block.get("name") == "Bash":
                cmd = str(inp.get("command", ""))
                if "scripts/lint.py" in cmd and "python" in cmd:
                    last_lint = pos
print("yes" if last_edit is not None and last_lint is not None and last_lint > last_edit else "no")
' "$1"
}
