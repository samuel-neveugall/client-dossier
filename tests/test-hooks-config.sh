#!/usr/bin/env bash
# tests/test-hooks-config.sh — PROTO-05 and PROTO-08, and the "all hooks" row
# of 03-VALIDATION.md: hooks/hooks.json is well formed and wired the way Claude
# Code runs it, and every hooks/*.py script is Python 3.8 standard library
# only, read-only, and finds the dossier root with the very same find_root as
# scripts/lint.py.
#
# REQUIRED_EVENTS lists the events hooks.json must declare. Plan 03-01 ships
# PreToolUse; plan 03-04 adds SessionStart and Stop by extending this line,
# and one end-to-end `sh -c` block per event at the bottom of this file.
set -u

# shellcheck source=./lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

REQUIRED_EVENTS='PreToolUse SessionStart Stop'
PRETOOLUSE_MATCHER='Write|Edit|MultiEdit|NotebookEdit|Bash'
HOOKS_JSON="$REPO_ROOT/hooks/hooks.json"

assert_file "$HOOKS_JSON"

# --- hooks.json parses and declares every required event ---
PARSE_STATUS=0
python3 -c 'import json, sys; json.load(open(sys.argv[1]))' "$HOOKS_JSON" 2>/dev/null || PARSE_STATUS=$?
assert_eq 0 "$PARSE_STATUS" 'hooks.json is valid JSON'

# One tab-separated line per declared hook: event, matcher (- when none),
# type, command, timeout. A placeholder keeps empty fields from collapsing,
# because tab is whitespace to `read`.
DECLARED="$(python3 - "$HOOKS_JSON" <<'PY' 2>/dev/null
import json, sys
data = json.load(open(sys.argv[1]))
for event, groups in data["hooks"].items():
    for group in groups:
        for hook in group.get("hooks", []):
            print("\t".join([
                event,
                group.get("matcher") or "-",
                str(hook.get("type")),
                str(hook.get("command")),
                str(hook.get("timeout")),
            ]))
PY
)"

for event in $REQUIRED_EVENTS; do
  if printf '%s\n' "$DECLARED" | cut -f1 | grep -qx "$event"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "FAIL: hooks.json declares no $event hook" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
done

COMMANDS=""
while IFS=$'\t' read -r event matcher type command timeout; do
  [ -n "$event" ] || continue
  if [ "$event" = PreToolUse ]; then
    assert_eq "$PRETOOLUSE_MATCHER" "$matcher" 'PreToolUse matcher is exactly the five tools'
  fi
  assert_eq command "$type" "$event hook type is command"
  # Shell form, the variable inside double quotes (a path with a space must
  # survive sh -c), and a script that exists next to hooks.json.
  if printf '%s' "$command" | grep -Eq '^python3 "\$\{CLAUDE_PLUGIN_ROOT\}/hooks/[a-z0-9-]+\.py"$'; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "FAIL: $event command is not python3 \"\${CLAUDE_PLUGIN_ROOT}/hooks/<name>.py\": $command" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  script="${command#*hooks/}"
  script="${script%\"}"
  assert_file "$REPO_ROOT/hooks/$script"
  case "$timeout" in
    ''|*[!0-9]*)
      echo "FAIL: $event timeout is not a whole number: '$timeout'" >&2
      TESTS_FAILED=$((TESTS_FAILED + 1))
      ;;
    *)
      if [ "$timeout" -ge 1 ] && [ "$timeout" -le 30 ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
      else
        echo "FAIL: $event timeout $timeout is outside 1..30" >&2
        TESTS_FAILED=$((TESTS_FAILED + 1))
      fi
      ;;
  esac
  COMMANDS="$COMMANDS$command"$'\n'
done <<EOF
$DECLARED
EOF

# --- every hooks/*.py: grammar, imports, APIs, read-only, find_root parity ---
LINT_BLOCK="$(sed -n '/^def find_root/,/^    return None$/p' "$(lint_py)")"
assert_eq 14 "$(printf '%s\n' "$LINT_BLOCK" | wc -l | tr -d ' ')" 'lint.py find_root block is 14 lines'

for script in "$REPO_ROOT"/hooks/*.py; do
  [ -e "$script" ] || continue
  name="$(basename "$script")"

  STATUS=0
  python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read(), feature_version=(3, 8))' "$script" 2>/dev/null || STATUS=$?
  assert_eq 0 "$STATUS" "$name parses with the Python 3.8 grammar"

  # Imports: json, os, sys, shlex, subprocess, and `from pathlib import Path`.
  STATUS=0
  python3 - "$script" <<'PY' 2>/dev/null || STATUS=$?
import ast, sys
tree = ast.parse(open(sys.argv[1]).read())
allowed = {"json", "os", "sys", "shlex", "subprocess"}
bad = []
for node in ast.walk(tree):
    if isinstance(node, ast.Import):
        bad += [a.name for a in node.names if a.name not in allowed]
    elif isinstance(node, ast.ImportFrom):
        names = [a.name for a in node.names]
        if not (node.module == "pathlib" and names == ["Path"]):
            bad.append("from %s import %s" % (node.module, ",".join(names)))
if bad:
    print("disallowed imports:", bad)
    sys.exit(1)
PY
  assert_eq 0 "$STATUS" "$name imports only the allowed standard library modules"

  # Python 3.9+ APIs that the 3.8 grammar check cannot see (RESEARCH Pitfall 7).
  NEWER="$(grep -nE 'is_relative_to|removeprefix|removesuffix|strict=|functools|@cache|\b(list|dict|tuple|set|frozenset)\[' "$script" || true)"
  assert_eq '' "$NEWER" "$name uses none of the Python 3.9+ APIs"

  # A hook never writes: no open() in a writing mode, no write helpers.
  STATUS=0
  python3 - "$script" <<'PY' 2>/dev/null || STATUS=$?
import ast, sys
tree = ast.parse(open(sys.argv[1]).read())
writers = {"write_text", "write_bytes", "unlink", "rmdir", "mkdir", "makedirs",
           "rmtree", "touch"}
os_writers = {"remove", "rename", "replace", "chmod", "symlink", "link", "truncate"}
bad = []
for node in ast.walk(tree):
    if not isinstance(node, ast.Call):
        continue
    func = node.func
    if isinstance(func, ast.Name) and func.id == "open":
        mode = None
        if len(node.args) > 1 and isinstance(node.args[1], ast.Constant):
            mode = node.args[1].value
        for kw in node.keywords:
            if kw.arg == "mode" and isinstance(kw.value, ast.Constant):
                mode = kw.value.value
        if isinstance(mode, str) and any(c in mode for c in "wax+"):
            bad.append("open(..., %r)" % mode)
    elif isinstance(func, ast.Attribute) and func.attr in writers:
        bad.append("." + func.attr)
    elif (isinstance(func, ast.Attribute) and func.attr in os_writers
          and isinstance(func.value, ast.Name) and func.value.id == "os"):
        bad.append("os." + func.attr)
if bad:
    print("writes:", bad)
    sys.exit(1)
PY
  assert_eq 0 "$STATUS" "$name opens no file for writing"

  HOOK_BLOCK="$(sed -n '/^def find_root/,/^    return None$/p' "$script")"
  if [ -n "$HOOK_BLOCK" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "FAIL: $name has no def find_root block" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  assert_eq "$LINT_BLOCK" "$HOOK_BLOCK" "$name find_root is byte-identical to scripts/lint.py's"
done

# --- each declared command, run through sh -c as Claude Code runs it ---
# declared_command EVENT — the first declared command of EVENT.
declared_command() {
  printf '%s' "$DECLARED" | awk -F'\t' -v ev="$1" '$1 == ev { print $4; exit }'
}

PRE_COMMAND="$(declared_command PreToolUse)"
START_COMMAND="$(declared_command SessionStart)"
STOP_COMMAND="$(declared_command Stop)"

# run_declared COMMAND PLUGIN_ROOT JSON — run COMMAND through `sh -c` with
# CLAUDE_PLUGIN_ROOT exported, storing the result like run_hook does.
run_declared() {
  local command="$1" root="$2" json="$3" err_file
  err_file="$(mktemp)"
  HOOK_STATUS=0
  HOOK_OUT="$(printf '%s' "$json" | CLAUDE_PLUGIN_ROOT="$root" sh -c "$command" 2>"$err_file")" || HOOK_STATUS=$?
  HOOK_ERR="$(cat "$err_file")"
  rm -f "$err_file"
}

if [ -n "$PRE_COMMAND" ]; then
  d=$(scratch_repo)
  python3 "$(init_py)" --target "$d" --language en \
    --counterpart 'Acme Consulting|ordering party|Jane Doe' >/dev/null 2>&1
  mkdir -p "$d/sources/transcripts"
  printf '%s\n' '@00:12 Jane Doe: We need the reprot by 2026-10-20.' \
    >"$d/sources/transcripts/2026-10-01_kickoff.txt"
  EDIT_JSON="$(hook_json PreToolUse "$d" Edit file_path "$d/sources/transcripts/2026-10-01_kickoff.txt")"

  run_declared "$PRE_COMMAND" "$REPO_ROOT" "$EDIT_JSON"
  assert_eq 0 "$HOOK_STATUS" 'sh -c: exit status 0'
  assert_eq deny "$(hook_field hookSpecificOutput.permissionDecision)" 'sh -c: an Edit under sources/ is denied'

  spaced="$(mktemp -d)/plugin root with space"
  mkdir -p "$(dirname "$spaced")"
  ln -s "$REPO_ROOT" "$spaced"
  run_declared "$PRE_COMMAND" "$spaced" "$EDIT_JSON"
  assert_eq 0 "$HOOK_STATUS" 'sh -c, plugin root with a space: exit status 0'
  assert_eq deny "$(hook_field hookSpecificOutput.permissionDecision)" 'sh -c, plugin root with a space: an Edit under sources/ is denied'
  rm -rf "$(dirname "$spaced")"

  run_declared "$PRE_COMMAND" "$REPO_ROOT" 'not json'
  assert_eq 0 "$HOOK_STATUS" 'sh -c with malformed stdin: exit status 0'
  assert_eq '' "$HOOK_OUT" 'sh -c with malformed stdin: empty stdout'

  # SessionStart (PROTO-04): from inside the scratch dossier the reminder
  # names the namespaced skill; the command runs from a plugin root with a
  # space too, and stays silent on malformed stdin.
  if [ -n "$START_COMMAND" ]; then
    START_JSON="$(hook_json SessionStart "$d" '' '' '')"
    run_declared "$START_COMMAND" "$REPO_ROOT" "$START_JSON"
    assert_eq 0 "$HOOK_STATUS" 'sh -c SessionStart: exit status 0'
    case "$(hook_field hookSpecificOutput.additionalContext)" in
      *client-dossier:dossier*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
      *)
        echo 'FAIL: sh -c SessionStart: additionalContext does not name client-dossier:dossier' >&2
        TESTS_FAILED=$((TESTS_FAILED + 1))
        ;;
    esac
    spaced="$(mktemp -d)/plugin root with space"
    mkdir -p "$(dirname "$spaced")"
    ln -s "$REPO_ROOT" "$spaced"
    run_declared "$START_COMMAND" "$spaced" "$START_JSON"
    assert_eq 0 "$HOOK_STATUS" 'sh -c SessionStart, plugin root with a space: exit status 0'
    case "$(hook_field hookSpecificOutput.additionalContext)" in
      *client-dossier:dossier*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
      *)
        echo 'FAIL: sh -c SessionStart, plugin root with a space: no reminder' >&2
        TESTS_FAILED=$((TESTS_FAILED + 1))
        ;;
    esac
    rm -rf "$(dirname "$spaced")"
    run_declared "$START_COMMAND" "$REPO_ROOT" 'not json'
    assert_eq 0 "$HOOK_STATUS" 'sh -c SessionStart with malformed stdin: exit status 0'
    assert_eq '' "$HOOK_OUT" 'sh -c SessionStart with malformed stdin: empty stdout'
  else
    echo 'FAIL: no SessionStart command to run through sh -c' >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  # Stop (PROTO-06, D-01): from a committed scratch dossier with an outbound
  # change the command prints a block decision; with stop_hook_active true it
  # prints nothing; malformed stdin is silent.
  if [ -n "$STOP_COMMAND" ]; then
    s=$(scratch_repo)
    python3 "$(init_py)" --target "$s" --language en \
      --counterpart 'Acme Consulting|ordering party|Jane Doe' >/dev/null 2>&1
    git -C "$s" add -A >/dev/null 2>&1
    git -C "$s" commit -qm scaffold >/dev/null 2>&1
    mkdir -p "$s/outbound/mails"
    printf '%s\n' 'Reply draft, written 2026-10-10.' >"$s/outbound/mails/2026-10-10_reply.md"
    STOP_JSON="$(python3 -c 'import json, sys; print(json.dumps({"hook_event_name": "Stop", "cwd": sys.argv[1], "stop_hook_active": sys.argv[2] == "true", "session_id": "test", "transcript_path": "/dev/null"}))' "$s" false)"
    run_declared "$STOP_COMMAND" "$REPO_ROOT" "$STOP_JSON"
    assert_eq 0 "$HOOK_STATUS" 'sh -c Stop: exit status 0'
    assert_eq block "$(hook_field decision)" 'sh -c Stop: an outbound change without a dossier change is blocked'
    ACTIVE_JSON="$(python3 -c 'import json, sys; print(json.dumps({"hook_event_name": "Stop", "cwd": sys.argv[1], "stop_hook_active": True}))' "$s")"
    run_declared "$STOP_COMMAND" "$REPO_ROOT" "$ACTIVE_JSON"
    assert_eq 0 "$HOOK_STATUS" 'sh -c Stop, stop_hook_active true: exit status 0'
    assert_eq '' "$HOOK_OUT" 'sh -c Stop, stop_hook_active true: empty stdout'
    spaced="$(mktemp -d)/plugin root with space"
    mkdir -p "$(dirname "$spaced")"
    ln -s "$REPO_ROOT" "$spaced"
    run_declared "$STOP_COMMAND" "$spaced" "$STOP_JSON"
    assert_eq 0 "$HOOK_STATUS" 'sh -c Stop, plugin root with a space: exit status 0'
    assert_eq block "$(hook_field decision)" 'sh -c Stop, plugin root with a space: blocked'
    rm -rf "$(dirname "$spaced")"
    run_declared "$STOP_COMMAND" "$REPO_ROOT" 'not json'
    assert_eq 0 "$HOOK_STATUS" 'sh -c Stop with malformed stdin: exit status 0'
    assert_eq '' "$HOOK_OUT" 'sh -c Stop with malformed stdin: empty stdout'
    rm -rf "$s"
  else
    echo 'FAIL: no Stop command to run through sh -c' >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  rm -rf "$d"
else
  echo 'FAIL: no PreToolUse command to run through sh -c' >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# --- the manifest validator reports nothing about hooks ---
if command -v claude >/dev/null 2>&1; then
  VALIDATE_STATUS=0
  VALIDATE_OUT="$(claude plugin validate "$REPO_ROOT" 2>&1)" || VALIDATE_STATUS=$?
  assert_eq 0 "$VALIDATE_STATUS" 'claude plugin validate exits 0'
  HOOK_LINES="$(printf '%s\n' "$VALIDATE_OUT" | grep -v '^Validating' | grep -i 'hook' || true)"
  assert_eq '' "$HOOK_LINES" 'claude plugin validate prints no hooks-related line'
else
  skip 'claude is not on PATH: claude plugin validate not run'
fi

finish
