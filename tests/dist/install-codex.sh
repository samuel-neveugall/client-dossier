#!/usr/bin/env bash
# tests/dist/install-codex.sh — the Codex marketplace install check
# (DIST-02, ROADMAP criterion 2, D-04, D-05, D-17).
#
# Installs the plugin end to end the way a Codex user would, from this
# repository's own marketplace listing (.agents/plugins/marketplace.json, a
# local path because the repository is private), into a throwaway Codex home:
#   1. a fresh `git clone` of HEAD checked out at the exact commit (tracked
#      files only);
#   2. `codex plugin marketplace add <clone>` and `codex plugin add
#      client-dossier@client-dossier`, with CODEX_HOME=<root>/cfg and
#      HOME=<root>/home under one mktemp root and a temporary working directory (no login needed);
#   3. `codex plugin list --json` shows the plugin installed and enabled at the
#      clone's version, from the local source; the cache copy holds the Codex
#      manifest, the skills and hooks/hooks.json;
#   4. `codex debug prompt-input` run from an empty folder lists exactly one
#      `client-dossier:<name>` per skills/ folder of the clone;
#   5. the real Claude Code, Codex and ~/.agents files are byte-identical
#      before and after (D-17), and the temporary root is removed on exit.
#
# Free: no login and no model call. It installs HEAD only, so commit first.
# Every CLI output goes through dist_redact (no home path in a logged run).
# Hook behaviour at run time is NOT exercised here: an isolated CODEX_HOME is
# not logged in and Codex asks the user to trust hooks in /hooks (documented,
# never claimed).
#
# Exit codes: 0 pass, 1 gate not met, 2 harness error.
# Usage: bash tests/dist/install-codex.sh
# Never run by tests/run.sh (the folder tests/dist/ is not globbed): run by the
# agent, the output kept under the phase's evidence/ folder.
set -u

# shellcheck source=./lib-dist.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib-dist.sh"

dist_init install-codex

command -v git >/dev/null 2>&1 || scenario_die "git not found on PATH"
command -v python3 >/dev/null 2>&1 || scenario_die "python3 not found on PATH"
dist_help_has codex plugin marketplace
dist_help_has codex plugin add
dist_help_has codex plugin list
dist_help_has codex 'plugin marketplace' add
dist_help_has codex 'plugin list' --json
dist_help_has codex debug prompt-input

BEFORE="$(dist_real_snapshot)"

CLONE="$DIST_ROOT/src/repo"
dist_clone_head "$CLONE"

# run_codex ARGS... — one codex call in the throwaway configuration from the
# temporary working directory; output (stdout and stderr) goes through
# dist_redact into stdout, and is kept unredacted in CODEX_OUT for parsing.
CODEX_OUT=""
run_codex() {
  local rc=0
  CODEX_OUT="$(cd "$DIST_ROOT/cwd" && CODEX_HOME="$DIST_ROOT/cfg" \
    HOME="$DIST_ROOT/home" codex "$@" 2>&1)" || rc=$?
  echo "\$ codex $*"
  printf '%s\n' "$CODEX_OUT" | dist_redact
  return "$rc"
}

VERSION="$(python3 -I -c '
import json, sys
print(json.load(open(sys.argv[1], encoding="utf-8"))["version"])
' "$CLONE/.codex-plugin/plugin.json")" || scenario_die "cannot read the Codex manifest version"

if run_codex plugin marketplace add "$CLONE"; then
  dist_ok "marketplace add exits 0"
else
  dist_bad "marketplace add failed"
  dist_real_unchanged "$BEFORE" || dist_bad "real configuration changed"
  dist_finish
fi
case "$CODEX_OUT" in
  *client-dossier*) dist_ok "marketplace add output names client-dossier" ;;
  *) dist_bad "marketplace add output does not name client-dossier" ;;
esac

if run_codex plugin add client-dossier@client-dossier; then
  dist_ok "plugin add exits 0"
else
  dist_bad "plugin add failed"
  dist_real_unchanged "$BEFORE" || dist_bad "real configuration changed"
  dist_finish
fi

# --- plugin list --json: installed, enabled, at the clone's version ----------
if run_codex plugin list --json; then
  dist_ok "plugin list --json exits 0"
else
  dist_bad "plugin list --json failed"
fi
LIST_REPORT="$(printf '%s' "$CODEX_OUT" | python3 -I -c '
import json, sys
plugin_id, want = sys.argv[1:3]
try:
    data = json.loads(sys.stdin.read())
except ValueError:
    print("bad\tplugin list --json is not valid JSON")
    sys.exit(0)
items = data.get("installed", []) if isinstance(data, dict) else []
item = next((i for i in items if i.get("pluginId") == plugin_id), None)
if item is None:
    print("bad\t" + plugin_id + " is not among the installed plugins")
    sys.exit(0)
print(("ok" if item.get("installed") is True else "bad") + "\t" + plugin_id + " is installed")
print(("ok" if item.get("enabled") is True else "bad") + "\t" + plugin_id + " is enabled")
print(("ok" if item.get("version") == want else "bad")
      + "\tinstalled version " + str(item.get("version")) + " equals the clone version " + want)
source = item.get("source") or {}
print(("ok" if source.get("source") == "local" else "bad")
      + "\tsource type is " + str(source.get("source")) + " (local expected)")
' client-dossier@client-dossier "$VERSION")"
while IFS=$'\t' read -r verdict text; do
  case "$verdict" in
    ok) dist_ok "$text" ;;
    bad) dist_bad "$text" ;;
  esac
done <<EOF
$LIST_REPORT
EOF

# --- the cache copy ----------------------------------------------------------
CACHE="$DIST_ROOT/cfg/plugins/cache/client-dossier/client-dossier/$VERSION"
if [ -d "$CACHE" ]; then
  dist_ok "cache folder exists: $(printf '%s' "$CACHE" | dist_redact)"
  for rel in .codex-plugin/plugin.json skills/dossier/SKILL.md hooks/hooks.json; do
    if [ -f "$CACHE/$rel" ]; then
      dist_ok "cache copy holds $rel"
    else
      dist_bad "cache copy lacks $rel"
    fi
  done
else
  dist_bad "cache folder is missing: $(printf '%s' "$CACHE" | dist_redact)"
fi

# --- the skills Codex exposes, from a fresh empty folder ---------------------
EXPECTED=""
for dir in "$CLONE"/skills/*/; do
  [ -f "${dir}SKILL.md" ] || continue
  EXPECTED="$EXPECTED $(basename "$dir")"
done
EMPTY="$DIST_ROOT/cwd/empty"
mkdir -p "$EMPTY" || scenario_die "cannot create $EMPTY"
PROMPT_RC=0
PROMPT_OUT="$(cd "$EMPTY" && CODEX_HOME="$DIST_ROOT/cfg" HOME="$DIST_ROOT/home" \
  codex debug prompt-input hi 2>&1)" || PROMPT_RC=$?
echo "\$ codex debug prompt-input hi   (from an empty folder; the plugin's skill entries only)"
printf '%s\n' "$PROMPT_OUT" | python3 -I -c '
import re, sys
text = sys.stdin.read()
for name, path in re.findall(r"- (client-dossier:[A-Za-z0-9_-]+): .*?\(file: ([^)]+)\)", text):
    print("skill " + name + " -> " + path)
' | dist_redact
if [ "$PROMPT_RC" -eq 0 ]; then
  dist_ok "debug prompt-input exits 0"
else
  dist_bad "debug prompt-input failed (exit $PROMPT_RC)"
fi
SKILL_REPORT="$(printf '%s' "$PROMPT_OUT" | python3 -I -c '
import re, sys
expected = sorted(sys.argv[1].split())
found = sorted(set(re.findall(r"client-dossier:([A-Za-z0-9_-]+)", sys.stdin.read())))
print(("ok" if found == expected else "bad")
      + "\tprompt-input lists client-dossier:<name> for " + " ".join(found)
      + (" (equals the " + str(len(expected)) + " skills/ folders)" if found == expected
         else " but skills/ holds " + " ".join(expected)))
' "$EXPECTED")"
while IFS=$'\t' read -r verdict text; do
  case "$verdict" in
    ok) dist_ok "$text" ;;
    bad) dist_bad "$text" ;;
  esac
done <<EOF
$SKILL_REPORT
EOF

echo "note: hooks run on Codex after the user trusts them in /hooks; their run-time behaviour is documentation-backed here (an isolated CODEX_HOME is not logged in)"

# --- the real configuration is untouched (D-17) ------------------------------
if dist_real_unchanged "$BEFORE"; then
  dist_ok "real Claude Code, Codex and ~/.agents configuration byte-identical"
else
  dist_bad "real configuration changed"
fi

dist_finish
