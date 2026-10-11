#!/usr/bin/env bash
# tests/test-manifests.sh — DIST-01 and DIST-02, plan 07-01, D-02/D-03/D-14:
# the four distribution manifests are complete, carry one identity, are written
# the way scripts/release.sh will rewrite them (so a version bump touches only
# the version lines), and the Claude Code manifest and marketplace pass
# `claude plugin validate`.
#
# Static section: python3 reads the JSON files through argv and prints
# `label<TAB>expected<TAB>actual` lines, consumed by an assert_eq loop. A
# missing file prints `missing` as the actual value.
#
# CLI section (D-03): the root CLAUDE.md stays, so `validate .` carries exactly
# one warning (that file) and `--strict` exits 1. Every `claude` call runs with
# CLAUDE_CONFIG_DIR and HOME pointed at mktemp directories, because validate
# writes `.claude.json` and `backups/` into the configuration it uses. The
# section is skipped, never failed, when claude is not on PATH.
set -u

# shellcheck source=./lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CLAUDE_PLUGIN="$REPO_ROOT/.claude-plugin/plugin.json"
CLAUDE_MARKET="$REPO_ROOT/.claude-plugin/marketplace.json"
CODEX_PLUGIN="$REPO_ROOT/.codex-plugin/plugin.json"
CODEX_MARKET="$REPO_ROOT/.agents/plugins/marketplace.json"

# --- static checks -----------------------------------------------------------
CHECKS="$(python3 -I - "$CLAUDE_PLUGIN" "$CLAUDE_MARKET" "$CODEX_PLUGIN" "$CODEX_MARKET" <<'PY' 2>&1
import json, os, re, sys

claude_plugin, claude_market, codex_plugin, codex_market = sys.argv[1:5]
REPO_URL = "https://github.com/samuel-neveugall/client-dossier"
IDENTITY = ["name", "version", "description", "author", "homepage",
            "repository", "license", "keywords"]


def load(path):
    if not os.path.isfile(path):
        return None
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def emit(label, expected, actual):
    print("\t".join([label, str(expected), str(actual)]))


def keys(data):
    return " ".join(data.keys())


def email_keys(node, found):
    """Collect every key whose name looks like an e-mail field, at any depth."""
    if isinstance(node, dict):
        for key, value in node.items():
            if "mail" in key.lower():
                found.append(key)
            email_keys(value, found)
    elif isinstance(node, list):
        for item in node:
            email_keys(item, found)
    return found


files = {
    "claude plugin.json": claude_plugin,
    "claude marketplace.json": claude_market,
    "codex plugin.json": codex_plugin,
    "codex marketplace.json": codex_market,
}

# Present files: byte-equal to the canonical dump, no e-mail field at any depth.
for label, path in files.items():
    if not os.path.isfile(path):
        continue
    with open(path, encoding="utf-8") as handle:
        raw = handle.read()
    canonical = json.dumps(json.loads(raw), indent=2, ensure_ascii=False) + "\n"
    emit(label + " is byte-equal to json.dumps indent 2", "yes",
         "yes" if raw == canonical else "no")
    emit(label + " has no e-mail field", "", " ".join(email_keys(json.loads(raw), [])))

# --- Claude manifest ---
plugin = load(claude_plugin)
if plugin is None:
    emit("claude plugin.json exists", "yes", "missing")
else:
    emit("claude plugin keys", " ".join(IDENTITY), keys(plugin))
    emit("claude name", "client-dossier", plugin.get("name"))
    emit("claude version is semver-shaped", "yes",
         "yes" if re.match(r"^[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.+-]+)?$",
                           str(plugin.get("version"))) else "no")
    author = plugin.get("author")
    emit("claude author keys", "name",
         keys(author) if isinstance(author, dict) else "not an object")
    emit("claude author name", "Samuel Neveu",
         author.get("name") if isinstance(author, dict) else "missing")
    emit("claude homepage", REPO_URL, plugin.get("homepage"))
    emit("claude repository", REPO_URL, plugin.get("repository"))
    emit("claude license", "MIT", plugin.get("license"))
    words = plugin.get("keywords")
    emit("claude keywords is a non-empty list of strings", "yes",
         "yes" if isinstance(words, list) and words
         and all(isinstance(w, str) and w for w in words) else "no")
    for forbidden in ("skills", "agents", "commands", "hooks", "mcpServers"):
        emit("claude plugin.json has no " + forbidden + " key", "no",
             "yes" if forbidden in plugin else "no")

# --- Claude marketplace ---
market = load(claude_market)
if market is None:
    emit("claude marketplace.json exists", "yes", "missing")
else:
    emit("claude marketplace keys", "name owner description plugins", keys(market))
    emit("claude marketplace name", "client-dossier", market.get("name"))
    owner = market.get("owner")
    emit("claude marketplace owner name", "Samuel Neveu",
         owner.get("name") if isinstance(owner, dict) else "missing")
    emit("claude marketplace description is non-empty", "yes",
         "yes" if isinstance(market.get("description"), str)
         and market["description"].strip() else "no")
    entries = market.get("plugins")
    emit("claude marketplace holds exactly one entry", "1",
         len(entries) if isinstance(entries, list) else "not a list")
    if isinstance(entries, list) and len(entries) == 1:
        entry = entries[0]
        emit("claude marketplace entry keys", "name source", keys(entry))
        emit("claude marketplace entry name", "client-dossier", entry.get("name"))
        emit("claude marketplace entry source", "./", entry.get("source"))
PY
)"

while IFS=$'\t' read -r label expected actual; do
  [ -n "$label" ] || continue
  assert_eq "$expected" "$actual" "$label"
done <<EOF
$CHECKS
EOF

# D-14: the Codex manifest is one of the two markers status.py needs to find
# the linter.
assert_grep '\.codex-plugin/plugin\.json' "$REPO_ROOT/skills/dossier-status/scripts/status.py"

# --- claude plugin validate (D-03) -------------------------------------------
if ! command -v claude >/dev/null 2>&1; then
  skip 'claude not on PATH: validate not run'
else
  V_CFG="$(mktemp -d)"
  V_HOME="$(mktemp -d)"
  trap 'rm -rf "$V_CFG" "$V_HOME"' EXIT

  # run_validate ARGS... — validate from the repository root in the throwaway
  # configuration; stdout in VAL_OUT, exit status in VAL_STATUS.
  run_validate() {
    VAL_STATUS=0
    VAL_OUT="$(cd "$REPO_ROOT" && CLAUDE_CONFIG_DIR="$V_CFG" HOME="$V_HOME" \
      claude plugin validate "$@" 2>&1)" || VAL_STATUS=$?
  }

  run_validate .
  assert_eq 0 "$VAL_STATUS" 'claude plugin validate . exits 0'

  run_validate . --json
  assert_eq 0 "$VAL_STATUS" 'claude plugin validate . --json exits 0'
  # Walk the whole document: every list under a key `errors` is empty, the
  # lists under keys `warnings` hold exactly one item, which names CLAUDE.md.
  COUNTS="$(printf '%s' "$VAL_OUT" | python3 -I -c '
import json, sys
text = sys.stdin.read()
try:
    doc = json.loads(text)
except ValueError:
    print("invalid-json invalid-json")
    sys.exit(0)
errors, warnings = [], []
def walk(node):
    if isinstance(node, dict):
        for key, value in node.items():
            if key == "errors" and isinstance(value, list):
                errors.extend(value)
            elif key == "warnings" and isinstance(value, list):
                warnings.extend(value)
            else:
                walk(value)
    elif isinstance(node, list):
        for item in node:
            walk(item)
walk(doc)
print(len(errors), len(warnings), "yes" if len(warnings) == 1 and "CLAUDE.md" in json.dumps(warnings[0]) else "no")
')"
  set -- $COUNTS
  assert_eq 0 "${1:-}" 'validate JSON report holds no error'
  assert_eq 1 "${2:-}" 'validate JSON report holds exactly one warning'
  assert_eq yes "${3:-}" 'the one validate warning is about the root CLAUDE.md'

  run_validate .claude-plugin/plugin.json
  assert_eq 0 "$VAL_STATUS" 'claude plugin validate .claude-plugin/plugin.json exits 0'

  run_validate --strict .
  assert_eq 1 "$VAL_STATUS" 'claude plugin validate --strict . exits 1 (D-03: the root CLAUDE.md stays)'
fi

finish
