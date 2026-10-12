#!/usr/bin/env bash
# command-smoke.sh — the Phase 7 command smoke for 07-UAT (DIST-04 as amended by D-18), plan 07-09.
# Two paid headless Haiku runs with `--plugin-dir` on a scratch dossier holding one outbound file
# without a status header:
#   1. /client-dossier:dossier-lint   the one plugin command: listed, runs scripts/lint.py through
#                                     Bash, relays every finding id and the exit code of a direct run
#   2. /client-dossier:dossier-status a task skill as a slash command: its SKILL.md is expanded
#                                     (a Bash command uses the expanded skill-folder path), never the
#                                     shadowing sign `already loaded above`
# Neither run may modify the dossier. Not a test file: never run by tests/run.sh.
# Usage: bash .planning/phases/07-manifests-docs-distribution/evidence/uat/command-smoke.sh [OUTDIR]
# Exit codes: 0 both pass, 1 a check failed, 2 harness error.
#
# Isolation note: the run needs the real Claude Code login, which an isolated CLAUDE_CONFIG_DIR or
# HOME loses (`claude auth status` reports loggedIn false in all three variants, probed). The run
# therefore uses the real session with `--setting-sources project,local` and
# `--no-session-persistence` (run_claude), and this script proves the real plugin and settings
# files byte-identical before and after (dist_real_snapshot).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../../../../.." && pwd)"
export REPO_ROOT
export SCENARIO_MODEL=haiku
export SCENARIO_BUDGET_USD=0.25
# shellcheck source=/dev/null
. "$REPO_ROOT/tests/scenarios/lib-scenario.sh"
# shellcheck source=/dev/null
. "$REPO_ROOT/tests/dist/lib-dist.sh"

OUTDIR="${1:-$HERE}"
mkdir -p "$OUTDIR" || exit 2
OUTDIR="$(cd "$OUTDIR" && pwd)"
scenario_preflight

dist_init command-smoke
cfg_before="$(dist_real_snapshot)"
mkdir -p "$DIST_ROOT/tmp" "$DIST_ROOT/raw" || scenario_die "cannot create the work folders"
# The scratch dossier lives under the throwaway root, so dist_redact rewrites its path.
TMPDIR="$DIST_ROOT/tmp"
export TMPDIR
RAW="$DIST_ROOT/raw"

today="$(date +%F)"
dir="$(build_dossier)" || exit 2
mkdir -p "$dir/outbound/mails" || scenario_die "cannot create outbound/mails"
printf 'A plain sentence for the command smoke, written without a status header.\n' \
  >"$dir/outbound/mails/${today}_note.md"

# The direct lint run: its exit code (must be 1) and its finding ids are the reference.
direct_out="$(python3 "$REPO_ROOT/scripts/lint.py" "$dir" 2>&1)"
direct_rc=$?
[ "$direct_rc" -eq 1 ] || scenario_die "the direct lint run exited $direct_rc, expected 1"
ids="$(printf '%s\n' "$direct_out" | grep -oE '\[[A-Z]+[0-9]+\]' | sort -u | tr -d '[]' | tr '\n' ',' | sed 's/,$//')"
[ -n "$ids" ] || scenario_die "the direct lint run printed no finding id"
echo "direct lint: exit $direct_rc, finding ids: $ids"

# --- python checks over a stream, one verdict token per line ------------------------------------
check_lint_stream() {
  python3 -I - "$1" "$2" "$3" <<'PY'
import json, re, sys

path, ids, direct_rc = sys.argv[1], sys.argv[2].split(","), sys.argv[3]
events = []
with open(path, encoding="utf-8", errors="replace") as fh:
    for line in fh:
        line = line.strip()
        if line.startswith("{"):
            try:
                events.append(json.loads(line))
            except ValueError:
                pass

listed = False
for ev in events:
    if ev.get("type") == "system" and ev.get("subtype") == "init":
        cmds = ev.get("slash_commands") or []
        listed = any(
            (c if isinstance(c, str) else str(c.get("name", ""))) == "client-dossier:dossier-lint"
            for c in cmds
        )
        break
print(("ok" if listed else "fail") + ":command-listed")

ran = False
for ev in events:
    if ev.get("type") != "assistant":
        continue
    for block in (ev.get("message") or {}).get("content") or []:
        if isinstance(block, dict) and block.get("type") == "tool_use" and block.get("name") == "Bash":
            if "scripts/lint.py" in str((block.get("input") or {}).get("command", "")):
                ran = True
print(("ok" if ran else "fail") + ":bash-ran-lint.py")

text = ""
for ev in events:
    if ev.get("type") == "result":
        text = str(ev.get("result", ""))
missing = [i for i in ids if i not in text]
print(("ok" if not missing else "fail") + ":relays-finding-ids" + ("" if not missing else "(" + "+".join(missing) + ")"))
rc_re = re.compile(r"exit(ed)?( code| status)?( with| of| is|:)? *" + re.escape(direct_rc), re.I)
print(("ok" if rc_re.search(text) else "fail") + ":relays-exit-" + direct_rc)
PY
}

check_status_stream() {
  python3 -I - "$1" <<'PY'
import json, sys

path = sys.argv[1]
events = []
raw = ""
with open(path, encoding="utf-8", errors="replace") as fh:
    for line in fh:
        raw += line
        line = line.strip()
        if line.startswith("{"):
            try:
                events.append(json.loads(line))
            except ValueError:
                pass


def texts(ev):
    content = (ev.get("message") or {}).get("content")
    if isinstance(content, str):
        yield "text", content
    elif isinstance(content, list):
        for block in content:
            if not isinstance(block, dict):
                continue
            if block.get("type") == "text":
                yield "text", str(block.get("text", ""))
            elif block.get("type") == "tool_result":
                inner = block.get("content")
                if isinstance(inner, list):
                    inner = "\n".join(str(b.get("text", "")) for b in inner if isinstance(b, dict))
                yield "tool_result", str(inner)


where = "none"
for ev in events:
    if ev.get("type") == "assistant":
        continue
    for kind, body in texts(ev):
        if any(l.strip() == "# dossier-status" for l in body.split("\n")):
            if where == "none" or kind == "text":
                where = "injected" if kind == "text" else "tool_result"
# stream-json does not echo the first user message, which is where a slash command puts the
# expanded SKILL.md. The observable proof of the expansion is a Bash command that uses the path
# ${CLAUDE_SKILL_DIR} expanded to: the model can only know it from the rendered SKILL.md.
cmds = []
for ev in events:
    if ev.get("type") != "assistant":
        continue
    for block in (ev.get("message") or {}).get("content") or []:
        if isinstance(block, dict) and block.get("type") == "tool_use" and block.get("name") == "Bash":
            cmds.append(str((block.get("input") or {}).get("command", "")))
expanded = any("/skills/dossier-status/scripts/status.py" in c and "CLAUDE_SKILL_DIR" not in c for c in cmds)
print(("ok" if expanded else "fail") + ":skill-body-expanded-path-used")
print("info:heading-in-stream=" + where)
print(("fail" if "already loaded above" in raw else "ok") + ":no-shadowing-sign")
ran = any("status.py" in c and "test -x" not in c for c in cmds)
print("info:bash-ran-status.py=" + ("yes" if ran else "no"))
PY
}

# one run: NAME PROMPT CHECKER [CHECKER_ARGS...]; leaves $RAW/NAME.jsonl and appends a tsv row
ROWS=""
FAILED=0
smoke_run() {
  local name="$1" prompt="$2" checker="$3" sha_before sha_after toks tok checks verdict model cost iserr
  shift 3
  sha_before="$(tree_sha "$dir")"
  run_claude "$dir" "$RAW/$name.jsonl" "$prompt" yes
  sha_after="$(tree_sha "$dir")"
  toks="$("$checker" "$RAW/$name.jsonl" "$@")"
  if [ "$sha_before" = "$sha_after" ]; then
    toks="$toks
ok:dossier-unchanged"
  else
    toks="$toks
fail:dossier-unchanged"
  fi
  checks="$(printf '%s\n' "$toks" | tr '\n' ';' | sed 's/;$//')"
  verdict=PASS
  case "$toks" in *fail:*) verdict=FAIL ;; esac
  model="$(python3 -I - "$RAW/$name.jsonl" <<'PY'
import json, sys
names = []
with open(sys.argv[1], encoding="utf-8", errors="replace") as fh:
    for line in fh:
        line = line.strip()
        if line.startswith("{"):
            try:
                ev = json.loads(line)
            except ValueError:
                continue
            if ev.get("type") == "result" and isinstance(ev.get("modelUsage"), dict):
                names = sorted(ev["modelUsage"])
print("+".join(names) if names else "MISSING")
PY
)"
  cost="$(jsonl_result_field "$RAW/$name.jsonl" total_cost_usd)"
  iserr="$(jsonl_result_field "$RAW/$name.jsonl" is_error)"
  [ "$iserr" = false ] || verdict=FAIL
  [ "$verdict" = PASS ] || FAILED=1
  ROWS="${ROWS}${name}	${verdict}	${checks}	${model}	${cost}	${iserr}
"
  echo "$name: $verdict ($checks) model=$model cost=$cost is_error=$iserr"
}

smoke_run lint-smoke '/client-dossier:dossier-lint' check_lint_stream "$ids" "$direct_rc"
smoke_run status-smoke '/client-dossier:dossier-status' check_status_stream

printf 'name\tverdict\tchecks\tmodel\tcost_usd\tis_error\n%s' "$ROWS" >"$RAW/smoke-summary.tsv"

# redact into OUTDIR, then scrub
for f in lint-smoke.jsonl status-smoke.jsonl smoke-summary.tsv; do
  dist_redact <"$RAW/$f" >"$OUTDIR/$f"
done
if grep -q '[/]Users[/]'"$OUTDIR/lint-smoke.jsonl" "$OUTDIR/status-smoke.jsonl" "$OUTDIR/smoke-summary.tsv"; then
  scenario_die "a home path survived dist_redact in the evidence"
fi
scrub_check "$OUTDIR/lint-smoke.jsonl" "$OUTDIR/status-smoke.jsonl" "$OUTDIR/smoke-summary.tsv" \
  || scenario_die "scrub_check failed on the evidence"

if dist_real_unchanged "$cfg_before"; then :; else FAILED=1; fi

if [ "$FAILED" -eq 0 ]; then
  echo "SMOKE command-smoke: PASS"
  exit 0
fi
echo "SMOKE command-smoke: FAIL"
exit 1
