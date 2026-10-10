#!/usr/bin/env bash
# tests/scenarios/selftest-ingest.sh — free self-test of the paid INGEST-05
# harness (tests/scenarios/ingest-transcript.sh) and of the helpers it adds to
# tests/scenarios/lib-scenario.sh (plan 04-02; D-10, D-12, D-13).
#
# ingest-transcript.sh normally drives a real, authenticated `claude -p` (money,
# network). This script proves every helper, verdict, gate and harness-error path
# against a generated fake `claude` instead, so the verdict logic is trusted
# before a single model call is paid for. SCENARIO_CLAUDE points the harness at
# the fake. Not named test-*.sh and living in a subdirectory, so tests/run.sh
# never globs it (it is run by hand and by the plan's verify step).
#
# Bash 3.2 safe, no arrays.
set -u

# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

SCEN_DIR="$REPO_ROOT/tests/scenarios"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ---------------------------------------------------------------------------
# Section 1: the helpers added to lib-scenario.sh (D-12 agents, D-13 backdating)
# ---------------------------------------------------------------------------

# call FN ARGS... — runs a lib-scenario.sh function in a subshell, as
# selftest.sh does for the pointer-removal function.
call() {
  (. "$SCEN_DIR/lib-scenario.sh" && "$@")
}

# Synthetic stream-json files, one JSON object per line.
INIT_STR="$WORK/init-strings.jsonl"
INIT_OBJ="$WORK/init-objects.jsonl"
INIT_NONE="$WORK/init-nokey.jsonl"
printf '%s\n' 'not json at all' \
  '{"type":"system","subtype":"init","agents":["general-purpose","client-dossier:fact-extractor"]}' >"$INIT_STR"
printf '%s\n' '{"type":"system","subtype":"init","agents":[{"name":"general-purpose"},{"name":"client-dossier:fact-extractor"}]}' >"$INIT_OBJ"
printf '%s\n' '{"type":"system","subtype":"init","skills":["update-config"]}' >"$INIT_NONE"

assert_eq yes "$(call jsonl_has_agent "$INIT_STR" client-dossier:fact-extractor)" 'jsonl_has_agent: string entries, exact name'
assert_eq yes "$(call jsonl_has_agent "$INIT_OBJ" client-dossier:fact-extractor)" 'jsonl_has_agent: object entries, exact name'
assert_eq no "$(call jsonl_has_agent "$INIT_STR" fact-extractor)" 'jsonl_has_agent: a suffix is not an exact match'
assert_eq no "$(call jsonl_has_agent "$INIT_NONE" client-dossier:fact-extractor)" 'jsonl_has_agent: no agents key'
assert_eq no "$(call jsonl_has_agent "$WORK/absent.jsonl" client-dossier:fact-extractor)" 'jsonl_has_agent: missing file'
assert_eq yes "$(call jsonl_has_agent_prefix "$INIT_STR" client-dossier:)" 'jsonl_has_agent_prefix: prefix hit (strings)'
assert_eq yes "$(call jsonl_has_agent_prefix "$INIT_OBJ" client-dossier:)" 'jsonl_has_agent_prefix: prefix hit (objects)'
assert_eq no "$(call jsonl_has_agent_prefix "$INIT_NONE" client-dossier:)" 'jsonl_has_agent_prefix: no agents key'
assert_eq no "$(call jsonl_has_agent_prefix "$INIT_STR" other:)" 'jsonl_has_agent_prefix: prefix miss'

DISP_AGENT="$WORK/dispatch-agent.jsonl"
DISP_TASK="$WORK/dispatch-task.jsonl"
DISP_GENERAL="$WORK/dispatch-general.jsonl"
DISP_SKILL="$WORK/dispatch-skill.jsonl"
printf '%s\n' 'noise' \
  '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Agent","input":{"subagent_type":"client-dossier:fact-extractor"}}]}}' >"$DISP_AGENT"
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Task","input":{"subagent_type":"client-dossier:fact-extractor"}}]}}' >"$DISP_TASK"
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Agent","input":{"subagent_type":"general-purpose"}}]}}' >"$DISP_GENERAL"
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"client-dossier:fact-extractor"}}]}}' >"$DISP_SKILL"

assert_eq yes "$(call jsonl_agent_dispatched "$DISP_AGENT" fact-extractor)" 'jsonl_agent_dispatched: Agent tool_use'
assert_eq yes "$(call jsonl_agent_dispatched "$DISP_TASK" fact-extractor)" 'jsonl_agent_dispatched: Task tool_use'
assert_eq no "$(call jsonl_agent_dispatched "$DISP_GENERAL" fact-extractor)" 'jsonl_agent_dispatched: a general-purpose subagent'
assert_eq no "$(call jsonl_agent_dispatched "$DISP_SKILL" fact-extractor)" 'jsonl_agent_dispatched: a Skill tool_use naming the suffix'
assert_eq no "$(call jsonl_agent_dispatched "$WORK/absent.jsonl" fact-extractor)" 'jsonl_agent_dispatched: missing file'

# backdate_last_updated on a scaffold built by the real init.py.
BD="$(mktemp -d "$WORK/bd.XXXXXX")"
python3 "$(init_py)" --target "$BD" --language en \
  --counterpart 'Acme Consulting|ordering party|Jane Doe' >/dev/null 2>&1
SEVEN="ACTORS HISTORY LEARNINGS TONE CHANNELS OPEN-QUESTIONS RELATIONSHIP"
mkdir -p "$WORK/bd-before"
for n in $SEVEN; do cp "$BD/dossier/$n.md" "$WORK/bd-before/$n.md"; done
status=0
call backdate_last_updated "$BD" 2026-09-01 >/dev/null 2>"$WORK/bd.err" || status=$?
assert_eq 0 "$status" 'backdate_last_updated: exit 0 on a real scaffold'
for n in $SEVEN; do
  assert_eq 'Last updated: 2026-09-01' "$(grep -m1 '^Last updated:' "$BD/dossier/$n.md")" "backdate_last_updated: $n first Last updated line"
  # Every other line is untouched: the diff holds exactly the one replaced line.
  changed="$(diff "$WORK/bd-before/$n.md" "$BD/dossier/$n.md" | grep -c '^>')"
  assert_eq 1 "$changed" "backdate_last_updated: $n changes one line only"
done
status=0
python3 "$(lint_py)" "$BD" >/dev/null 2>&1 || status=$?
assert_eq 0 "$status" 'backdate_last_updated: lint.py still exits 0'

# A living file with no Last updated: line is a harness error.
BD2="$(mktemp -d "$WORK/bd.XXXXXX")"
python3 "$(init_py)" --target "$BD2" --language en \
  --counterpart 'Acme Consulting|ordering party|Jane Doe' >/dev/null 2>&1
sed '/^Last updated:/d' "$BD2/dossier/TONE.md" >"$WORK/tone.tmp" && cp "$WORK/tone.tmp" "$BD2/dossier/TONE.md"
status=0
call backdate_last_updated "$BD2" 2026-09-01 >/dev/null 2>"$WORK/bd2.err" || status=$?
assert_eq 2 "$status" 'backdate_last_updated: a file without Last updated exits 2'
assert_grep '^HARNESS ERROR:' "$WORK/bd2.err"

finish
