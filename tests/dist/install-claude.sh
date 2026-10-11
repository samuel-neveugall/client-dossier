#!/usr/bin/env bash
# tests/dist/install-claude.sh — the Claude Code marketplace install check
# (DIST-01, ROADMAP criterion 1, D-04, D-17).
#
# Installs the plugin end to end the way a user would, from a local marketplace
# (the repository is private, D-04), into a throwaway Claude Code configuration:
#   1. a fresh `git clone` of HEAD checked out at the exact commit (tracked
#      files only: a local-path install copies the whole working tree);
#   2. `claude plugin marketplace add` and `claude plugin install
#      client-dossier@client-dossier`, with CLAUDE_CONFIG_DIR and HOME under one
#      mktemp root and a temporary working directory;
#   3. `claude plugin list --json` shows the plugin enabled at the clone's
#      version; `claude plugin details` shows every skill folder, both agents
#      and the three hook events; the installed copy holds the files a user
#      needs (skills, hooks, the linter, every commands/*.md of the clone);
#   4. the real Claude Code and Codex configuration files are byte-identical
#      before and after (D-17), and the temporary root is removed on exit.
#
# Free: no login and no model call. It installs HEAD only, so commit first.
# Every CLI output goes through dist_redact (no home path in a logged run).
#
# Exit codes: 0 pass, 1 gate not met, 2 harness error.
# Usage: bash tests/dist/install-claude.sh
# Never run by tests/run.sh (the folder tests/dist/ is not globbed): run by the
# agent, the output kept under the phase's evidence/ folder.
set -u

# shellcheck source=./lib-dist.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib-dist.sh"

dist_init install-claude

command -v git >/dev/null 2>&1 || scenario_die "git not found on PATH"
command -v python3 >/dev/null 2>&1 || scenario_die "python3 not found on PATH"
dist_help_has claude plugin marketplace
dist_help_has claude plugin install
dist_help_has claude plugin details
dist_help_has claude plugin list
dist_help_has claude 'plugin marketplace' add
dist_help_has claude 'plugin list' --json

BEFORE="$(dist_real_snapshot)"

CLONE="$DIST_ROOT/src/repo"
dist_clone_head "$CLONE"

# run_claude ARGS... — one claude call in the throwaway configuration from the
# temporary working directory; output (stdout and stderr) goes through
# dist_redact into stdout, and is kept unredacted in CLAUDE_OUT for parsing.
CLAUDE_OUT=""
run_claude() {
  local rc=0
  CLAUDE_OUT="$(cd "$DIST_ROOT/cwd" && CLAUDE_CONFIG_DIR="$DIST_ROOT/cfg" \
    HOME="$DIST_ROOT/home" claude "$@" 2>&1)" || rc=$?
  echo "\$ claude $*"
  printf '%s\n' "$CLAUDE_OUT" | dist_redact
  return "$rc"
}

if run_claude plugin marketplace add "$CLONE"; then
  dist_ok "marketplace add exits 0"
else
  dist_bad "marketplace add failed"
  dist_real_unchanged "$BEFORE" || dist_bad "real configuration changed"
  dist_finish
fi

if run_claude plugin install client-dossier@client-dossier; then
  dist_ok "plugin install exits 0"
else
  dist_bad "plugin install failed"
  dist_real_unchanged "$BEFORE" || dist_bad "real configuration changed"
  dist_finish
fi

# --- plugin list --json: enabled, at the clone's version ---------------------
if run_claude plugin list --json; then
  dist_ok "plugin list --json exits 0"
else
  dist_bad "plugin list --json failed"
fi
LIST_REPORT="$(printf '%s' "$CLAUDE_OUT" | python3 -I -c '
import json, sys
plugin_id, manifest = sys.argv[1:3]
want = json.load(open(manifest, encoding="utf-8"))["version"]
try:
    items = json.loads(sys.stdin.read())
except ValueError:
    print("bad\tplugin list --json is not valid JSON")
    sys.exit(0)
item = next((i for i in items if i.get("id") == plugin_id), None)
if item is None:
    print("bad\t" + plugin_id + " is not in plugin list")
    sys.exit(0)
print(("ok" if item.get("enabled") is True else "bad") + "\t" + plugin_id + " is enabled")
print(("ok" if item.get("version") == want else "bad") + "\tinstalled version " + str(item.get("version")) + " equals the clone version " + want)
print("path\t" + str(item.get("installPath")))
' client-dossier@client-dossier "$CLONE/.claude-plugin/plugin.json")"
INSTALL_PATH=""
while IFS=$'\t' read -r verdict text; do
  case "$verdict" in
    ok) dist_ok "$text" ;;
    bad) dist_bad "$text" ;;
    path) INSTALL_PATH="$text" ;;
  esac
done <<EOF
$LIST_REPORT
EOF

# --- plugin details: skills, agents, hooks -----------------------------------
SKILLS=""
for dir in "$CLONE"/skills/*/; do
  [ -f "${dir}SKILL.md" ] || continue
  SKILLS="$SKILLS $(basename "$dir")"
done
AGENTS=""
for file in "$CLONE"/agents/*.md; do
  [ -f "$file" ] || continue
  AGENTS="$AGENTS $(basename "$file" .md)"
done
HOOKS="$(python3 -I -c '
import json, sys
print(" ".join(json.load(open(sys.argv[1], encoding="utf-8"))["hooks"]))
' "$CLONE/hooks/hooks.json")"

if run_claude plugin details client-dossier@client-dossier; then
  dist_ok "plugin details exits 0"
else
  dist_bad "plugin details failed"
fi
DETAILS_REPORT="$(printf '%s' "$CLAUDE_OUT" | python3 -I -c '
import re, sys
skills, agents, hooks = (a.split() for a in sys.argv[1:4])
text = sys.stdin.read()


def section(word, wanted):
    match = re.search(r"^\s*" + word + r" \((\d+)\)[ \t]+(.*)$", text, re.M)
    if match is None:
        print("bad\tplugin details has no \"" + word + " (N)\" line")
        return
    count = int(match.group(1))
    names = re.sub(r"\s*\(.*$", "", match.group(2))
    listed = [n.strip() for n in names.split(",") if n.strip()]
    print(("ok" if count == len(wanted) else "bad")
          + "\t" + word + " (" + str(count) + ") equals " + str(len(wanted)) + " in the clone")
    missing = [n for n in wanted if n not in listed]
    print(("ok" if not missing else "bad")
          + "\t" + word + " line names " + ("every one of " + " ".join(wanted)
                                              if not missing else "all but " + " ".join(missing)))


section("Skills", skills)
section("Agents", agents)
section("Hooks", hooks)
' "$SKILLS" "$AGENTS" "$HOOKS")"
while IFS=$'\t' read -r verdict text; do
  case "$verdict" in
    ok) dist_ok "$text" ;;
    bad) dist_bad "$text" ;;
  esac
done <<EOF
$DETAILS_REPORT
EOF

# --- the installed copy ------------------------------------------------------
if [ -n "$INSTALL_PATH" ] && [ -d "$INSTALL_PATH" ]; then
  dist_ok "installPath exists: $(printf '%s' "$INSTALL_PATH" | dist_redact)"
  for rel in skills/dossier/SKILL.md hooks/hooks.json scripts/lint.py; do
    if [ -f "$INSTALL_PATH/$rel" ]; then
      dist_ok "installed copy holds $rel"
    else
      dist_bad "installed copy lacks $rel"
    fi
  done
  # Generic on purpose (zero commands today): no later plan edits this script.
  for file in "$CLONE"/commands/*.md; do
    [ -f "$file" ] || continue
    rel="commands/$(basename "$file")"
    if [ -f "$INSTALL_PATH/$rel" ]; then
      dist_ok "installed copy holds $rel"
    else
      dist_bad "installed copy lacks $rel"
    fi
  done
else
  dist_bad "installPath is missing or not a directory"
fi

# --- the real configuration is untouched (D-17) ------------------------------
if dist_real_unchanged "$BEFORE"; then
  dist_ok "real Claude Code and Codex configuration byte-identical"
else
  dist_bad "real configuration changed"
fi

dist_finish
