#!/usr/bin/env bash
# tests/scenarios/lib-scenario.sh — building blocks of the headless pressure
# scenarios (PROTO-07, D-08).
#
# Sourced by tests/scenarios/fix-typo.sh and, in Phases 4-6, by their own
# scenario files. It is NOT run by tests/run.sh: a scenario costs model calls
# and needs an authenticated `claude`, so it lives in a subdirectory and none
# of its files is named test-*.sh. tests/scenarios/selftest.sh proves it for
# free against a fake `claude`.
#
# Source-safe: defines variables and functions only, runs nothing. Bash 3.2
# (macOS), no arrays, no associative arrays, python3 standard library only.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# The claude binary, the model and the per-run budget cap. The budget flag is
# the only run-time cap: macOS has no `timeout` command.
SCENARIO_CLAUDE="${SCENARIO_CLAUDE:-claude}"
SCENARIO_MODEL="${SCENARIO_MODEL:-sonnet}"
SCENARIO_BUDGET_USD="${SCENARIO_BUDGET_USD:-1}"

# scenario_die MSG — a harness error (exit 2), never a RED/GREEN verdict.
scenario_die() {
  echo "HARNESS ERROR: $1" >&2
  exit 2
}

# scenario_preflight — the claude binary must exist and its --help must
# mention every flag run_claude passes. Claude Code ships near-daily and `-p`
# may turn bare or lose a flag; better a loud stop than a contaminated run.
scenario_preflight() {
  local help flag
  command -v "$SCENARIO_CLAUDE" >/dev/null 2>&1 \
    || scenario_die "claude binary not found: $SCENARIO_CLAUDE"
  help="$("$SCENARIO_CLAUDE" --help 2>&1)" \
    || scenario_die "'$SCENARIO_CLAUDE --help' failed"
  for flag in --setting-sources --strict-mcp-config --model --permission-mode \
    --allowedTools --permission-prompts --max-budget-usd --no-session-persistence \
    --output-format --plugin-dir; do
    case "$help" in
      *"$flag"*) ;;
      *) scenario_die "claude --help does not mention $flag, which the harness passes" ;;
    esac
  done
}

# build_dossier — a fresh scratch dossier, built by the real init.py, in a
# `mktemp -d` outside any memory-file ancestor. Echoes its path. Callers use
# DIR=$(build_dossier) || exit 2: the die below exits only the command
# substitution, the caller's `|| exit 2` stops the run.
build_dossier() {
  local d parent
  d="$(mktemp -d)" || scenario_die "mktemp -d failed"
  # A parent CLAUDE.md or AGENTS.md would be loaded into the run's context and
  # contaminate it.
  parent="$(dirname "$d")"
  while :; do
    if [ -e "$parent/CLAUDE.md" ] || [ -e "$parent/AGENTS.md" ]; then
      scenario_die "an ancestor of $d holds a CLAUDE.md or AGENTS.md ($parent): it would leak into the run"
    fi
    [ "$parent" = "/" ] && break
    [ "$parent" = "." ] && break
    parent="$(dirname "$parent")"
  done
  git init -q "$d" >/dev/null 2>&1 || scenario_die "git init failed in $d"
  git -C "$d" config user.name "Scenario Runner"
  git -C "$d" config user.email "scenario@example.invalid"
  git -C "$d" config commit.gpgsign false
  python3 "$REPO_ROOT/skills/dossier-init/scripts/init.py" \
    --target "$d" \
    --language en \
    --counterpart 'Acme Consulting|ordering party|Jane Doe' \
    --confidential-name Acme \
    --confidential-name 'Acme Consulting' >/dev/null 2>&1 \
    || scenario_die "init.py failed to scaffold $d"
  [ ! -e "$d/.claude" ] || scenario_die "the scaffold holds a .claude/ folder (workspace trust, T-03-09)"
  echo "$d"
}

# --- P-01 (PROVISIONAL) -----------------------------------------------------
# strip_agents_pointer DIR
#
# PROVISIONAL (P-01, .planning/phases/03-protocol-skill-hooks/03-CONTEXT.md,
# awaiting Samuel).
#
# What it does: deletes the AGENTS.md that init.py wrote into the scratch
# dossier, so the plugin is the only variable between the baseline and plugin
# variants.
#
# Why: with the protocol pointer present, the no-plugin baseline refused to edit
# the transcript without filing anything -- neither RED nor GREEN -- so D-10's
# "RED at least once" could not be met (RESEARCH Pitfall 1).
#
# Reversion: drop the call in fix-typo.sh, the harness note it prints and the
# P-01 block of selftest.sh, then rerun the scenario and re-record the evidence.
#
# It dies (harness error) when DIR/AGENTS.md is absent -- the scaffold contract
# changed -- or when DIR/CLAUDE.md exists, and otherwise removes DIR/AGENTS.md
# only.
strip_agents_pointer() {
  local dir="$1"
  [ -f "$dir/AGENTS.md" ] \
    || scenario_die "$dir has no AGENTS.md: the init.py scaffold contract changed (P-01)"
  [ ! -e "$dir/CLAUDE.md" ] \
    || scenario_die "$dir holds a CLAUDE.md: removing only AGENTS.md would not remove the pointer (P-01)"
  rm -f "$dir/AGENTS.md"
}
# --- end P-01 (PROVISIONAL) --------------------------------------------------

# commit_baseline DIR — commits everything, echoes the commit id the run is
# later diffed against.
commit_baseline() {
  local dir="$1"
  git -C "$dir" add -A >/dev/null 2>&1 || scenario_die "git add failed in $dir"
  git -C "$dir" commit -q -m "scenario baseline" >/dev/null 2>&1 \
    || scenario_die "git commit failed in $dir"
  git -C "$dir" rev-parse HEAD
}

# run_claude DIR OUTFILE PROMPT WITH_PLUGIN — one headless run from DIR,
# stdout and stderr into OUTFILE (an absolute path). WITH_PLUGIN is yes or no.
#   --setting-sources project,local  no user settings: no global hooks, plugins
#                                    or ~/.claude/CLAUDE.md
#   --strict-mcp-config              drops connector MCP servers
#   --permission-prompts none        nothing waits on a human
#   --no-session-persistence         leaves no session on disk
# stdin is /dev/null: without it every run waits 3 s and warns. Never --bare
# (needs an API key and drops the skill listing).
run_claude() {
  local dir="$1" outfile="$2" prompt="$3" with_plugin="$4"
  set -- -p "$prompt" \
    --setting-sources project,local \
    --strict-mcp-config \
    --model "$SCENARIO_MODEL" \
    --permission-mode acceptEdits \
    --allowedTools Bash \
    --permission-prompts none \
    --max-budget-usd "$SCENARIO_BUDGET_USD" \
    --no-session-persistence \
    --output-format stream-json --verbose
  if [ "$with_plugin" = yes ]; then
    set -- "$@" --plugin-dir "$REPO_ROOT"
  fi
  (cd "$dir" && "$SCENARIO_CLAUDE" "$@" </dev/null >"$outfile" 2>&1)
  return 0
}

# jsonl_init_field FILE KEY — KEY of the first system/init event. Scalars are
# printed plain, lists and objects (and booleans) as JSON, MISSING when absent.
jsonl_init_field() {
  python3 -c '
import json, sys
path, key = sys.argv[1], sys.argv[2]
found = None
try:
    fh = open(path, encoding="utf-8", errors="replace")
except OSError:
    print("MISSING")
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
        if isinstance(ev, dict) and ev.get("type") == "system" and ev.get("subtype") == "init":
            found = ev
            break
if found is None or key not in found:
    print("MISSING")
else:
    v = found[key]
    print(v if isinstance(v, str) else json.dumps(v))
' "$1" "$2"
}

# jsonl_result_field FILE KEY — KEY of the LAST result event, same printing
# rules as jsonl_init_field.
jsonl_result_field() {
  python3 -c '
import json, sys
path, key = sys.argv[1], sys.argv[2]
found = None
try:
    fh = open(path, encoding="utf-8", errors="replace")
except OSError:
    print("MISSING")
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
        if isinstance(ev, dict) and ev.get("type") == "result":
            found = ev
if found is None or key not in found:
    print("MISSING")
else:
    v = found[key]
    print(v if isinstance(v, str) else json.dumps(v))
' "$1" "$2"
}

# jsonl_has_skill FILE NAME — yes when the init event's skills list holds
# NAME exactly (entries may be strings or objects with a name), else no.
jsonl_has_skill() {
  _jsonl_skills_match "$1" "$2" exact
}

# jsonl_has_skill_prefix FILE PREFIX — yes when any listed skill starts with
# PREFIX.
jsonl_has_skill_prefix() {
  _jsonl_skills_match "$1" "$2" prefix
}

_jsonl_skills_match() {
  python3 -c '
import json, sys
path, wanted, mode = sys.argv[1], sys.argv[2], sys.argv[3]
skills = []
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
        if isinstance(ev, dict) and ev.get("type") == "system" and ev.get("subtype") == "init":
            skills = ev.get("skills") or []
            break
names = []
for s in skills:
    if isinstance(s, str):
        names.append(s)
    elif isinstance(s, dict) and isinstance(s.get("name"), str):
        names.append(s["name"])
if mode == "exact":
    hit = wanted in names
else:
    hit = any(n.startswith(wanted) for n in names)
print("yes" if hit else "no")
' "$1" "$2" "$3"
}

# jsonl_skill_invoked FILE WORD — yes when any assistant tool_use named Skill
# has an input whose JSON text contains WORD AND its tool_result (matched by
# tool_use_id) came back with is_error not true (R4-m7: a denied call is not an
# invocation). Loose on the input on purpose: the exact input shape is not a
# documented contract (RESEARCH A5).
jsonl_skill_invoked() {
  python3 -c '
import json, sys
path, word = sys.argv[1], sys.argv[2]
uses = set()
results = {}
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
        if not isinstance(ev, dict) or ev.get("type") not in ("assistant", "user"):
            continue
        msg = ev.get("message")
        content = msg.get("content") if isinstance(msg, dict) else None
        if not isinstance(content, list):
            continue
        for block in content:
            if not isinstance(block, dict):
                continue
            if ev.get("type") == "assistant" and block.get("type") == "tool_use":
                if (
                    block.get("name") == "Skill"
                    and word in json.dumps(block.get("input", {}))
                ):
                    if isinstance(block.get("id"), str):
                        uses.add(block["id"])
            elif ev.get("type") == "user" and block.get("type") == "tool_result":
                if isinstance(block.get("tool_use_id"), str):
                    results[block["tool_use_id"]] = block.get("is_error") is True
# R4-m7: a call counts only when its tool_result came back and is not an error
# (a permission denial is a tool_result with is_error true).
print("yes" if any(i in results and not results[i] for i in uses) else "no")
' "$1" "$2"
}

# --- Phase 4 additions (plan 04-02) -----------------------------------------

# jsonl_has_agent FILE NAME — D-12. yes when the first system/init event's
# agents list holds NAME exactly (entries may be strings or objects with a
# name), else no (also when the key or the file is absent).
jsonl_has_agent() {
  _jsonl_agents_match "$1" "$2" exact
}

# jsonl_has_agent_prefix FILE PREFIX — D-12. yes when any listed agent starts
# with PREFIX (the contamination check of the no-plugin variants).
jsonl_has_agent_prefix() {
  _jsonl_agents_match "$1" "$2" prefix
}

# _jsonl_agents_match FILE WANTED MODE — the shared body, modelled on
# _jsonl_skills_match but reading the init event's `agents`.
_jsonl_agents_match() {
  python3 -c '
import json, sys
path, wanted, mode = sys.argv[1], sys.argv[2], sys.argv[3]
agents = []
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
        if isinstance(ev, dict) and ev.get("type") == "system" and ev.get("subtype") == "init":
            agents = ev.get("agents") or []
            break
names = []
for a in agents:
    if isinstance(a, str):
        names.append(a)
    elif isinstance(a, dict) and isinstance(a.get("name"), str):
        names.append(a["name"])
if mode == "exact":
    hit = wanted in names
else:
    hit = any(n.startswith(wanted) for n in names)
print("yes" if hit else "no")
' "$1" "$2" "$3"
}

# jsonl_agent_dispatched FILE SUFFIX — D-12. yes when an assistant tool_use
# named Agent or Task has an input subagent_type ending in SUFFIX. Both names
# are matched: in Claude Code 2.1.x the init tools list says Task while the
# tool_use is named Agent (RESEARCH "State of the Art"). A Skill tool_use that
# merely mentions the suffix does not count. As for skills (R4-m7), the call
# counts only when its tool_result came back with is_error not true.
jsonl_agent_dispatched() {
  python3 -c '
import json, sys
path, word = sys.argv[1], sys.argv[2]
uses = set()
results = {}
async_ids = set()
task_of = {}
completed = set()
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
        if (
            isinstance(ev, dict)
            and ev.get("type") == "system"
            and ev.get("subtype") == "task_notification"
            and ev.get("status") == "completed"
        ):
            for key in ("tool_use_id", "task_id"):
                if isinstance(ev.get(key), str):
                    completed.add(ev[key])
            continue
        if not isinstance(ev, dict) or ev.get("type") not in ("assistant", "user"):
            continue
        msg = ev.get("message")
        content = msg.get("content") if isinstance(msg, dict) else None
        if not isinstance(content, list):
            continue
        for block in content:
            if not isinstance(block, dict):
                continue
            if ev.get("type") == "assistant" and block.get("type") == "tool_use":
                if (
                    block.get("name") in ("Agent", "Task")
                    and isinstance(block.get("input"), dict)
                    and str(block["input"].get("subagent_type", "")).endswith(word)
                ):
                    if isinstance(block.get("id"), str):
                        uses.add(block["id"])
            elif ev.get("type") == "user" and block.get("type") == "tool_result":
                if isinstance(block.get("tool_use_id"), str):
                    tid = block["tool_use_id"]
                    results[tid] = block.get("is_error") is True
                    tur = ev.get("tool_use_result")
                    text = json.dumps(block.get("content"))
                    if (
                        isinstance(tur, dict) and tur.get("status") == "async_launched"
                    ) or "Async agent launched" in text:
                        # M3: an async dispatch is only "launched" here; the
                        # task_id is the agentId the launch result carries.
                        async_ids.add(tid)
                        if isinstance(tur, dict) and isinstance(tur.get("agentId"), str):
                            task_of[tid] = tur["agentId"]
# R4-m7: a call counts only when its tool_result came back and is not an error
# (a permission denial is a tool_result with is_error true).
# M3: an asynchronous dispatch counts only once a task_notification of status
# completed exists for it (matched by tool_use_id or by task_id).
def ok(i):
    if i not in results or results[i]:
        return False
    if i in async_ids:
        return i in completed or task_of.get(i) in completed
    return True
print("yes" if any(ok(i) for i in uses) else "no")
' "$1" "$2"
}

# backdate_last_updated DIR DATE — D-13 (RESEARCH Pitfall 6). init.py renders
# every living file with today as `Last updated:`, so a same-day scenario could
# never see a refresh. This rewrites the first `Last updated: YYYY-MM-DD` of
# each of the seven living files to `Last updated: DATE` and changes no other
# line. It dies (harness error) when a living file is missing or holds no such
# line: the scaffold contract changed.
backdate_last_updated() {
  local dir="$1" date="$2"
  python3 -c '
import re, sys
root, date = sys.argv[1], sys.argv[2]
names = ("ACTORS", "HISTORY", "LEARNINGS", "TONE", "CHANNELS", "OPEN-QUESTIONS", "RELATIONSHIP")
pattern = re.compile(r"^Last updated: [0-9]{4}-[0-9]{2}-[0-9]{2}")
for name in names:
    path = "{}/dossier/{}.md".format(root, name)
    try:
        with open(path, encoding="utf-8", newline="") as fh:
            lines = fh.read().split("\n")
    except OSError as exc:
        sys.stderr.write("{}: {}\n".format(path, exc))
        sys.exit(1)
    for i, line in enumerate(lines):
        if pattern.match(line):
            lines[i] = "Last updated: " + date + line[len("Last updated: YYYY-MM-DD"):]
            break
    else:
        sys.stderr.write("{}: no Last updated: line\n".format(path))
        sys.exit(1)
    with open(path, "w", encoding="utf-8", newline="") as fh:
        fh.write("\n".join(lines))
' "$dir" "$date" \
    || scenario_die "backdate_last_updated failed in $dir: a living file has no Last updated: line (D-13)"
}

# --- end Phase 4 additions ----------------------------------------------------

# file_sha FILE — sha256 (python3 hashlib, portable), MISSING when the file is
# gone.
file_sha() {
  python3 -c '
import hashlib, sys
try:
    with open(sys.argv[1], "rb") as fh:
        print(hashlib.sha256(fh.read()).hexdigest())
except OSError:
    print("MISSING")
' "$1"
}

# tree_sha DIR — one sha256 over every regular file under DIR (relative path
# and content, sorted), so a changed, added, renamed or deleted file changes it;
# MISSING when DIR is gone.
tree_sha() {
  python3 -c '
import hashlib, os, sys
root = sys.argv[1]
if not os.path.isdir(root):
    print("MISSING")
    sys.exit(0)
digest = hashlib.sha256()
for base, dirs, files in os.walk(root):
    dirs.sort()
    for name in sorted(files):
        path = os.path.join(base, name)
        digest.update(os.path.relpath(path, root).encode("utf-8", "surrogateescape") + b"\0")
        try:
            with open(path, "rb") as fh:
                digest.update(hashlib.sha256(fh.read()).hexdigest().encode())
        except OSError:
            digest.update(b"UNREADABLE")
        digest.update(b"\n")
print(digest.hexdigest())
' "$1"
}

# added_lines DIR BASE SUBDIR — the lines added under SUBDIR since commit BASE
# (git diff -U0 against BASE, not the index, so an agent that commits is still
# measured), plus every line of the untracked files under SUBDIR.
added_lines() {
  local dir="$1" base="$2" sub="$3" f
  git -C "$dir" diff -U0 "$base" -- "$sub" 2>/dev/null \
    | grep '^+' | grep -v '^+++' | sed 's/^+//'
  git -C "$dir" ls-files --others --exclude-standard -- "$sub" 2>/dev/null \
    | while IFS= read -r f; do
      cat "$dir/$f"
      printf '\n'
    done
  return 0
}

# scrub_check FILE... — non-zero with a message when a file contains an API key
# prefix (sk-ant-) or this repository's git user email. Run before evidence is
# copied into the repository (T-03-11).
scrub_check() {
  local email f rc=0
  email="$(git -C "$REPO_ROOT" config user.email 2>/dev/null || true)"
  for f in "$@"; do
    [ -f "$f" ] || continue
    if grep -q -- 'sk-ant-' "$f"; then
      echo "scrub_check: $f contains 'sk-ant-'" >&2
      rc=1
    fi
    if [ -n "$email" ] && grep -qF -- "$email" "$f"; then
      echo "scrub_check: $f contains the git user email" >&2
      rc=1
    fi
    # Warning only (A/R-F6): a home path is not a secret, and the existing
    # evidence already holds some; it never fails the check.
    if grep -qE -- '/Users/|\$HOME' "$f"; then
      echo "scrub_check: warning: $f holds a home path (/Users/ or \$HOME)" >&2
    fi
  done
  return "$rc"
}
