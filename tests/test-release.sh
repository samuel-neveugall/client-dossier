#!/usr/bin/env bash
# tests/test-release.sh — DIST-07 (D-01, D-09, D-16), plan 07-02: scripts/release.sh
# bumps both plugin manifests (and only the marketplace entries that already carry a
# version), writes the CHANGELOG heading, commits, and creates a LOCAL annotated tag.
# It refuses everything else and never contacts a remote.
#
# The script is ONLY ever run inside throwaway repositories made by `fixture` below,
# never in this repository (D-01: the real 1.0.0 run happens after the milestone
# audit). Each fixture gets a bare `origin` that must stay empty: that is the proof
# that nothing was pushed. No arrays (bash 3.2).
set -u

# shellcheck source=./lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# The scratch repositories must not inherit the maintainer's git configuration
# (signing, hooks path, templates): the test is about release.sh, not about it.
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_NOSYSTEM=1

RELEASE_SH="$REPO_ROOT/scripts/release.sh"
CLEAN_LIST="$(mktemp)"
TODAY="$(date +%F)"

CLAUDE_MANIFEST=.claude-plugin/plugin.json
CODEX_MANIFEST=.codex-plugin/plugin.json
CLAUDE_MARKET=.claude-plugin/marketplace.json
CODEX_MARKET=.agents/plugins/marketplace.json
CHANGELOG=CHANGELOG.md

# --- fixtures -----------------------------------------------------------------

# fixture [ENTRY_VERSION] — a scratch repository at version 0.1.0 with one commit and
# a bare `origin` that is never pushed to. With ENTRY_VERSION the Codex marketplace
# entry carries a version (the Claude one never does). Echoes the repository path.
fixture() {
  local entry="${1:-}" d remote
  d="$(scratch_repo)"
  remote="$(mktemp -d)"
  printf '%s\n%s\n' "$d" "$remote" >>"$CLEAN_LIST"
  python3 -I - "$d" "$entry" <<'PY'
import json, os, sys

root, entry = sys.argv[1], sys.argv[2]


def write(rel, data):
    path = os.path.join(root, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(json.dumps(data, indent=2, ensure_ascii=False) + "\n")


desc = "Dossier client — mémoire"
write(".claude-plugin/plugin.json",
      {"name": "client-dossier", "description": desc, "version": "0.1.0"})
write(".codex-plugin/plugin.json",
      {"name": "client-dossier", "description": desc, "version": "0.1.0"})
write(".claude-plugin/marketplace.json",
      {"name": "client-dossier", "plugins": [{"name": "client-dossier", "source": "./"}]})
codex_entry = {"name": "client-dossier", "source": {"source": "local", "path": "./"}}
if entry:
    codex_entry["version"] = entry
write(".agents/plugins/marketplace.json",
      {"name": "client-dossier", "plugins": [codex_entry]})
PY
  printf '# Changelog\n\nSee keepachangelog.com.\n\n## [Unreleased]\n\n### Added\n\n- The first bullet.\n' \
    >"$d/CHANGELOG.md"
  printf 'notes\n' >"$d/notes.txt"
  mkdir -p "$d/scripts"
  cp -p "$RELEASE_SH" "$d/scripts/release.sh"
  git -C "$d" add -- .
  git -C "$d" commit -q -m 'fixture'
  git init -q --bare "$remote"
  git -C "$d" remote add origin "$remote"
  echo "$d"
}

# commit_all DIR MESSAGE — commit whatever the test changed in a fixture.
commit_all() {
  git -C "$1" add -- .
  git -C "$1" commit -q -m "$2"
}

# set_manifest_version DIR FILE VERSION — rewrite one JSON file's version, same form.
set_manifest_version() {
  python3 -I - "$1/$2" "$3" <<'PY'
import json, sys

path, version = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as handle:
    data = json.load(handle)
data["version"] = version
with open(path, "w", encoding="utf-8") as handle:
    handle.write(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
PY
}

# manifest_version FILE — the "version" value of one JSON file ("none" when absent).
manifest_version() {
  python3 -I - "$1" <<'PY'
import json, sys

with open(sys.argv[1], encoding="utf-8") as handle:
    print(json.load(handle).get("version", "none"))
PY
}

# entry_version FILE — the "version" of the first plugins[] entry ("none" when absent).
entry_version() {
  python3 -I - "$1" <<'PY'
import json, sys

with open(sys.argv[1], encoding="utf-8") as handle:
    print(json.load(handle)["plugins"][0].get("version", "none"))
PY
}

# sha FILE — sha256 of a file, whichever tool this platform has.
sha() {
  if [ ! -f "$1" ]; then
    echo absent
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | cut -d' ' -f1
  else
    sha256sum "$1" | cut -d' ' -f1
  fi
}

# snapshot DIR — the records a refusal must leave untouched: HEAD, the tag list, the
# five files' hashes and the porcelain status.
snapshot() {
  local d="$1" f
  printf 'HEAD=%s\n' "$(git -C "$d" rev-parse HEAD)"
  printf 'TAGS=%s\n' "$(git -C "$d" tag -l | tr '\n' ' ')"
  for f in "$CLAUDE_MANIFEST" "$CODEX_MANIFEST" "$CLAUDE_MARKET" "$CODEX_MARKET" "$CHANGELOG"; do
    printf '%s=%s\n' "$f" "$(sha "$d/$f")"
  done
  printf 'STATUS=%s\n' "$(git -C "$d" status --porcelain --untracked-files=normal)"
}

REFUSE_ERR=""

# refuse LABEL DIR ARG... — run the fixture's release.sh from its .claude-plugin
# subfolder (which also proves the top-level cd) and assert: exit 1, stderr starting
# `release: `, the four records unchanged, and no file named PWNED anywhere.
# The stderr text is kept in REFUSE_ERR for err_has.
refuse() {
  local label="$1" d="$2" before after status=0 err_file
  shift 2
  before="$(snapshot "$d")"
  err_file="$(mktemp)"
  (cd "$d/.claude-plugin" && "$d/scripts/release.sh" "$@") >/dev/null 2>"$err_file" || status=$?
  REFUSE_ERR="$(cat "$err_file")"
  rm -f "$err_file"
  after="$(snapshot "$d")"
  assert_eq 1 "$status" "$label: exit 1"
  case "$REFUSE_ERR" in
    "release: "*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
    *)
      echo "FAIL: $label: stderr does not start with 'release: ' (got '$REFUSE_ERR')" >&2
      TESTS_FAILED=$((TESTS_FAILED + 1))
      ;;
  esac
  assert_eq "$before" "$after" "$label: HEAD, tags, files and status unchanged"
  assert_eq "" "$(find "$d" -name PWNED -not -path '*/.git/*' | head -1)" "$label: no PWNED file"
}

# err_has LABEL SUBSTRING — the last refusal's stderr holds SUBSTRING.
err_has() {
  case "$REFUSE_ERR" in
    *"$2"*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
    *)
      echo "FAIL: $1: stderr lacks '$2' (got '$REFUSE_ERR')" >&2
      TESTS_FAILED=$((TESTS_FAILED + 1))
      ;;
  esac
}

# release_ok LABEL DIR VERSION RUN_IN CHANGED — run release.sh VERSION from DIR/RUN_IN
# and assert the whole success contract. CHANGED is the newline-separated list of files
# HEAD must touch (git's order).
release_ok() {
  local label="$1" d="$2" version="$3" run_in="$4" changed="$5"
  local base head status=0 out_file err_file remote m n got want
  base="$(git -C "$d" rev-parse HEAD)"
  out_file="$(mktemp)"
  err_file="$(mktemp)"
  (cd "$d/$run_in" && "$d/scripts/release.sh" "$version") >"$out_file" 2>"$err_file" || status=$?
  assert_eq 0 "$status" "$label: exit 0"
  assert_eq "" "$(cat "$err_file")" "$label: nothing on stderr"
  assert_grep 'Nothing was pushed' "$out_file"
  assert_grep "tagged v$version locally" "$out_file"
  rm -f "$out_file" "$err_file"

  head="$(git -C "$d" rev-parse HEAD)"
  assert_eq "$version" "$(manifest_version "$d/$CLAUDE_MANIFEST")" "$label: Claude manifest version"
  assert_eq "$version" "$(manifest_version "$d/$CODEX_MANIFEST")" "$label: Codex manifest version"
  for m in "$CLAUDE_MANIFEST" "$CODEX_MANIFEST"; do
    n="$(git -C "$d" diff -U0 "$base" "$head" -- "$m" | grep -cE '^[-+] ')"
    assert_eq 2 "$n" "$label: $m changes exactly two lines"
    n="$(git -C "$d" diff -U0 "$base" "$head" -- "$m" | grep -E '^[-+] ' | grep -c '"version"')"
    assert_eq 2 "$n" "$label: $m: both changed lines are the version line"
  done

  got="$(grep -A2 -x '## \[Unreleased\]' "$d/$CHANGELOG")"
  want="$(printf '## [Unreleased]\n\n## [%s] - %s' "$version" "$TODAY")"
  assert_eq "$want" "$got" "$label: changelog heading under Unreleased"
  assert_eq 1 "$(grep -c -F "## [$version]" "$d/$CHANGELOG")" "$label: one heading for the version"
  assert_grep 'The first bullet' "$d/$CHANGELOG"

  assert_eq "chore(release): v$version" "$(git -C "$d" log -1 --format=%s)" "$label: commit subject"
  assert_eq "$changed" "$(git -C "$d" show --name-only --format= HEAD)" "$label: HEAD touches only the changed files"
  assert_eq tag "$(git -C "$d" cat-file -t "v$version")" "$label: tag is annotated"
  assert_eq "$head" "$(git -C "$d" rev-parse "v$version^{commit}")" "$label: tag points at HEAD"
  assert_eq "" "$(git -C "$d" status --porcelain --untracked-files=normal)" "$label: tree clean"
  remote="$(git -C "$d" config remote.origin.url)"
  assert_eq "" "$(git -C "$d" ls-remote origin)" "$label: origin lists nothing"
  assert_eq "" "$(git -C "$remote" for-each-ref)" "$label: bare origin holds no ref"
}

PLAIN_CHANGED="$(printf '%s\n%s\n%s' "$CLAUDE_MANIFEST" "$CODEX_MANIFEST" "$CHANGELOG")"

# --- static checks on the real script ------------------------------------------

assert_file "$RELEASE_SH"
assert_exec "$RELEASE_SH"
assert_eq '#!/usr/bin/env bash' "$(head -1 "$RELEASE_SH")" 'release.sh: shebang'
assert_grep_e '^set -euo pipefail$' "$RELEASE_SH"
BASH_N=0
bash -n "$RELEASE_SH" 2>/dev/null || BASH_N=$?
assert_eq 0 "$BASH_N" 'release.sh: bash -n'
assert_eq 0 "$(grep -cE '\bgit +(push|fetch|pull|ls-remote|remote)\b|curl|wget|\beval\b|\[@\]|=\(|=~' "$RELEASE_SH")" \
  'release.sh: no remote command, eval, array or regex test'
if [ "$(grep -c 'python3 -I - ' "$RELEASE_SH")" -ge 2 ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo 'FAIL: release.sh: fewer than two isolated python3 blocks fed through argv' >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# --- tracer: the success path, from the top and from a subfolder ----------------

d="$(fixture)"
assert_eq 0.1.0 "$(manifest_version "$d/$CLAUDE_MANIFEST")" 'fixture starts at 0.1.0'
MARKETS_BEFORE="$(sha "$d/$CLAUDE_MARKET") $(sha "$d/$CODEX_MARKET")"
release_ok 'release 1.0.0 from the top' "$d" 1.0.0 . "$PLAIN_CHANGED"
assert_eq "$MARKETS_BEFORE" "$(sha "$d/$CLAUDE_MARKET") $(sha "$d/$CODEX_MARKET")" \
  'release 1.0.0: both marketplaces are byte-unchanged'
assert_grep 'mémoire' "$d/$CLAUDE_MANIFEST"

d="$(fixture)"
release_ok 'release 1.0.0 from a subfolder' "$d" 1.0.0 .claude-plugin "$PLAIN_CHANGED"

# --- tracer: injection strings are refused and never executed -------------------

d="$(fixture)"
refuse 'injection ;' "$d" '1.0.0; touch PWNED'
err_has 'injection ;' 'not a semantic version'
refuse 'injection $()' "$d" '1.0.0$(touch PWNED)'
refuse 'injection backticks' "$d" '1.0.0`touch PWNED`'
refuse 'injection &&' "$d" '1.0.0 && touch PWNED'
refuse 'injection newline' "$d" $'1.0.0\ntouch PWNED'

# --- argument handling: each refusal on one shared fresh fixture ------------------

d="$(fixture)"
refuse 'no argument' "$d"
err_has 'no argument' 'usage'
refuse 'two arguments' "$d" 1.0.0 2.0.0
err_has 'two arguments' 'usage'
refuse 'empty argument' "$d" ''
err_has 'empty argument' 'not a semantic version'
refuse 'two components' "$d" 1.0
err_has 'two components' 'not a semantic version: 1.0'
refuse 'v prefix' "$d" v1.0.0
refuse 'leading zero' "$d" 01.0.0
refuse 'four components' "$d" 1.0.0.0
refuse 'empty pre-release' "$d" 1.0.0-
refuse 'option-like value' "$d" --help
err_has 'option-like value' 'not a semantic version: --help'
refuse 'newline stays visible' "$d" $'1.0.0\nx'
err_has 'newline stays visible' "\$'1.0.0\\nx'"
refuse 'command substitution stays inert' "$d" '1.0.0$(id)'
err_has 'command substitution stays inert' '\$\(id\)'

# --- dirty trees ---------------------------------------------------------------

d="$(fixture)"
printf 'stray\n' >"$d/untracked.txt"
refuse 'untracked file' "$d" 1.0.0
err_has 'untracked file' 'working tree is not clean'
assert_file "$d/untracked.txt"

d="$(fixture)"
printf 'edited\n' >>"$d/notes.txt"
refuse 'modified tracked file' "$d" 1.0.0
err_has 'modified tracked file' 'working tree is not clean'
assert_eq 'edited' "$(tail -1 "$d/notes.txt")" 'modified tracked file: the modification is kept'

# --- existing tags -------------------------------------------------------------

d="$(fixture)"
release_ok 'release before the duplicate' "$d" 1.0.0 . "$PLAIN_CHANGED"
refuse 'same version again' "$d" 1.0.0
err_has 'same version again' 'tag v1.0.0 already exists'

d="$(fixture)"
git -C "$d" tag v1.1.0
refuse 'manually created tag' "$d" 1.1.0
err_has 'manually created tag' 'tag v1.1.0 already exists'

# --- manifests -----------------------------------------------------------------

d="$(fixture)"
set_manifest_version "$d" "$CODEX_MANIFEST" 0.9.0
commit_all "$d" 'codex drifts'
refuse 'manifests disagree' "$d" 1.0.0
err_has 'manifests disagree' 'the two manifests disagree: 0.1.0 vs 0.9.0'

d="$(fixture)"
refuse 'already at the current version' "$d" 0.1.0
err_has 'already at the current version' 'already at 0.1.0'

d="$(fixture)"
rm -f "$d/$CODEX_MARKET"
commit_all "$d" 'codex marketplace removed'
refuse 'a file is missing' "$d" 1.0.0
err_has 'a file is missing' "missing file: $CODEX_MARKET"

# --- changelog -----------------------------------------------------------------

d="$(fixture)"
printf '# Changelog\n\n## [Unreleased-ish]\n\n- one\n' >"$d/$CHANGELOG"
commit_all "$d" 'no unreleased heading'
refuse 'changelog without Unreleased' "$d" 1.0.0
err_has 'changelog without Unreleased' 'exactly one'

d="$(fixture)"
printf '# Changelog\n\n## [Unreleased]\n\n- one\n\n## [Unreleased]\n\n- two\n' >"$d/$CHANGELOG"
commit_all "$d" 'two unreleased headings'
refuse 'changelog with two Unreleased' "$d" 1.0.0
err_has 'changelog with two Unreleased' 'exactly one'

d="$(fixture)"
printf '# Changelog\n\n## [Unreleased]\n\n## [1.0.0] - 2020-01-01\n\n- old\n' >"$d/$CHANGELOG"
commit_all "$d" 'changelog already holds 1.0.0'
refuse 'changelog already holds the heading' "$d" 1.0.0
err_has 'changelog already holds the heading' "already holds a '## [1.0.0]' heading"

# --- a failing commit leaves the five files as they were -------------------------

d="$(fixture)"
mkdir -p "$d/.git/hooks"
printf '#!/bin/sh\nexit 1\n' >"$d/.git/hooks/pre-commit"
chmod +x "$d/.git/hooks/pre-commit"
refuse 'commit hook rejects the release' "$d" 1.0.0
err_has 'commit hook rejects the release' 'the commit failed'

# --- outside any repository ----------------------------------------------------

plain="$(mktemp -d)"
printf '%s\n' "$plain" >>"$CLEAN_LIST"
cp -p "$RELEASE_SH" "$plain/release.sh"
OUT_STATUS=0
OUT_ERR="$( (cd "$plain" && ./release.sh 1.0.0) 2>&1 >/dev/null)" || OUT_STATUS=$?
assert_eq 1 "$OUT_STATUS" 'outside a repository: exit 1'
case "$OUT_ERR" in
  "release: not inside a git repository"*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  *)
    echo "FAIL: outside a repository: unexpected message '$OUT_ERR'" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    ;;
esac

# --- accepted forms ------------------------------------------------------------

d="$(fixture)"
release_ok 'pre-release 1.1.0-rc.1' "$d" 1.1.0-rc.1 . "$PLAIN_CHANGED"
assert_grep_e '^## \[1\.1\.0-rc\.1\] - [0-9]{4}-[0-9]{2}-[0-9]{2}$' "$d/$CHANGELOG"

d="$(fixture)"
release_ok 'build metadata 1.0.0+build.5' "$d" 1.0.0+build.5 . "$PLAIN_CHANGED"

# A marketplace entry that already carries a version follows the release; an entry
# without one never gains the key.
d="$(fixture 0.1.0)"
CODEX_CHANGED="$(printf '%s\n%s\n%s\n%s' "$CODEX_MARKET" "$CLAUDE_MANIFEST" "$CODEX_MANIFEST" "$CHANGELOG")"
release_ok 'entry that carries a version' "$d" 1.0.0 . "$CODEX_CHANGED"
assert_eq 1.0.0 "$(entry_version "$d/$CODEX_MARKET")" 'Codex entry with a version follows the release'
assert_eq none "$(entry_version "$d/$CLAUDE_MARKET")" 'Claude entry without a version never gains one'

# A second release on top of the first works and keeps both headings, newest first.
release_ok 'second release 1.0.1' "$d" 1.0.1 . "$CODEX_CHANGED"
assert_eq 1.0.1 "$(entry_version "$d/$CODEX_MARKET")" 'second release: Codex entry follows again'
HEADINGS="$(grep -E '^## \[' "$d/$CHANGELOG" | cut -d' ' -f1-2 | tr '\n' ' ')"
assert_eq '## [Unreleased] ## [1.0.1] ## [1.0.0] ' "$HEADINGS" 'second release: headings, newest first'

# --- cleanup --------------------------------------------------------------------

while IFS= read -r path; do
  [ -n "$path" ] && rm -rf "$path"
done <"$CLEAN_LIST"
rm -f "$CLEAN_LIST"

finish
