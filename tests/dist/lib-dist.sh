#!/usr/bin/env bash
# tests/dist/lib-dist.sh — helpers of the free, isolated install checks of
# Phase 7 (D-04, D-17).
#
# Sourced by tests/dist/install-claude.sh and, in later plans, by the Codex,
# skills and evidence scripts of the same folder. It is NOT run by
# tests/run.sh: the folder tests/dist/ is never globbed (no file in it is named
# test-*.sh), because an install check clones the repository and drives a real
# `claude` or `codex` binary. Those scripts are run by the agent.
#
# Source-safe: defines variables and functions only, runs nothing. The EXIT
# trap is set by dist_init, never at source time. Bash 3.2 (macOS), no arrays,
# python3 standard library only, always through `python3 -I`.
#
# It sources tests/scenarios/lib-scenario.sh for REPO_ROOT, scenario_die (exit
# 2, `HARNESS ERROR:` on stderr) and scrub_check, and copies none of them.
#
# Every CLI call of a dist script runs as
#   (cd "$DIST_ROOT/cwd" && CLAUDE_CONFIG_DIR=... HOME=... <cmd>)
# (Codex: CODEX_HOME=... HOME=...) with its output piped through dist_redact,
# so a logged run never carries the real home path.

# shellcheck source=../scenarios/lib-scenario.sh
source "$(dirname "${BASH_SOURCE[0]}")/../scenarios/lib-scenario.sh"

DIST_NAME=""
DIST_FAILED=0
DIST_ROOT=""
DIST_REAL_HOME=""
DIST_REAL_CLAUDE=""
DIST_REAL_CODEX=""

# dist_init NAME — records NAME and a zero failure count, captures the real
# configuration locations ONCE (before any variable is overridden), and creates
# the throwaway root with its cwd, home, cfg and src folders. The EXIT trap
# removes the root however the script ends.
dist_init() {
  DIST_NAME="$1"
  DIST_FAILED=0
  DIST_REAL_HOME="$HOME"
  DIST_REAL_CLAUDE="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  DIST_REAL_CODEX="${CODEX_HOME:-$HOME/.codex}"
  DIST_ROOT="$(mktemp -d)" || scenario_die "mktemp -d failed"
  mkdir -p "$DIST_ROOT/cwd" "$DIST_ROOT/home" "$DIST_ROOT/cfg" "$DIST_ROOT/src" \
    || scenario_die "cannot create the throwaway folders under $DIST_ROOT"
  # shellcheck disable=SC2064
  trap 'rm -rf "$DIST_ROOT"' EXIT
}

# dist_help_has BIN SUBWORDS NEEDLE — runs `BIN SUBWORDS --help` (SUBWORDS is
# split on spaces on purpose) in the throwaway configuration and stops the
# harness (exit 2) when BIN is not on PATH or NEEDLE is absent from the output.
# Claude Code and Codex ship often; better a loud stop than a command that no
# longer exists.
dist_help_has() {
  local bin="$1" sub="$2" needle="$3" out
  command -v "$bin" >/dev/null 2>&1 || scenario_die "$bin not found on PATH"
  # shellcheck disable=SC2086
  out="$(cd "$DIST_ROOT/cwd" && CLAUDE_CONFIG_DIR="$DIST_ROOT/cfg" \
    CODEX_HOME="$DIST_ROOT/cfg" HOME="$DIST_ROOT/home" "$bin" $sub --help 2>&1)" \
    || scenario_die "'$bin $sub --help' failed"
  case "$out" in
    *"$needle"*) ;;
    *) scenario_die "'$bin $sub --help' does not mention $needle" ;;
  esac
}

# dist_clone_head DEST — a fresh clone of the repository checked out detached
# at the exact HEAD commit (tracked files only: a local-path install copies
# the whole working tree, untracked files and .claude/ included, Pitfall 2).
dist_clone_head() {
  local dest="$1" sha got
  sha="$(git -C "$REPO_ROOT" rev-parse HEAD)" || scenario_die "cannot read HEAD of $REPO_ROOT"
  git clone -q --no-checkout "$REPO_ROOT" "$dest" || scenario_die "git clone failed"
  git -C "$dest" checkout -q --detach "$sha" || scenario_die "cannot check out $sha in the clone"
  got="$(git -C "$dest" rev-parse HEAD)"
  [ "$got" = "$sha" ] || scenario_die "the clone is at $got, expected $sha"
  echo "source: HEAD $(printf '%s' "$sha" | cut -c1-12)"
  if [ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]; then
    echo "note: uncommitted changes are not installed; this check installs HEAD only"
  fi
}

# dist_real_snapshot — one line `<value>  <label>` for each real configuration
# file a plugin install could touch: the sha256 of the file or `absent`; for
# the two skills folders, the sorted entry names. Labels use `~` and never
# print the home path. Pure read.
dist_real_snapshot() {
  python3 -I - "$DIST_REAL_HOME" "$DIST_REAL_CLAUDE" "$DIST_REAL_CODEX" <<'PY'
import hashlib, os, sys

home, claude, codex = sys.argv[1:4]


def label(path):
    if path == home or path.startswith(home + os.sep):
        return "~" + path[len(home):]
    return path


def digest(path):
    if not os.path.isfile(path):
        return "absent"
    with open(path, "rb") as handle:
        return hashlib.sha256(handle.read()).hexdigest()


def entries(path):
    if not os.path.isdir(path):
        return "absent"
    names = sorted(os.listdir(path))
    return ",".join(names) if names else "empty"


files = [
    os.path.join(claude, "settings.json"),
    os.path.join(claude, "plugins", "known_marketplaces.json"),
    os.path.join(claude, "plugins", "installed_plugins.json"),
    os.path.join(codex, "config.toml"),
    os.path.join(home, ".agents", "plugins", "marketplace.json"),
]
for path in files:
    print(digest(path) + "  " + label(path))
for path in (os.path.join(claude, "skills"), os.path.join(home, ".agents", "skills")):
    print(entries(path) + "  " + label(path) + " (entries)")
PY
}

# dist_real_unchanged BEFORE — recomputes the snapshot; prints `OK real
# configuration unchanged` and returns 0 when equal, else prints the labels
# that differ and returns 1.
dist_real_unchanged() {
  local before="$1" after
  after="$(dist_real_snapshot)"
  if [ "$before" = "$after" ]; then
    echo "OK real configuration unchanged"
    return 0
  fi
  echo "DIFFERENT real configuration:"
  diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") \
    | grep '^[<>]' | sed 's/^\([<>]\) [^ ]*  /\1 /'
  return 1
}

# dist_redact — filter, stdin to stdout: the repository path becomes <repo>,
# the throwaway root <tmp>, the real home `~`. Longest prefixes first, the
# symlink-resolved forms of the throwaway root and the repository included
# (macOS /var is /private/var). Values go through argv, never into the program.
dist_redact() {
  python3 -I -c '
import os, sys
repo, tmp, home = sys.argv[1:4]
pairs = []
for value, name in ((tmp, "<tmp>"), (repo, "<repo>"), (home, "~")):
    if not value:
        continue
    for form in {value, os.path.realpath(value)}:
        pairs.append((form, name))
pairs.sort(key=lambda p: -len(p[0]))
text = sys.stdin.read()
for form, name in pairs:
    text = text.replace(form, name)
sys.stdout.write(text)
' "$REPO_ROOT" "$DIST_ROOT" "$DIST_REAL_HOME"
}

# dist_ok LABEL / dist_bad LABEL — print the verdict line of one check; a
# failure is also written to stderr and counted in DIST_FAILED.
dist_ok() {
  echo "ok: $1"
}

dist_bad() {
  echo "FAIL: $1"
  echo "FAIL: $1" >&2
  DIST_FAILED=$((DIST_FAILED + 1))
}

# dist_finish — the last line of a dist script: `DIST <NAME>: PASS` and exit 0
# when no check failed, else `DIST <NAME>: FAIL` and exit 1 (the EXIT trap of
# dist_init removes the throwaway root).
dist_finish() {
  if [ "$DIST_FAILED" -eq 0 ]; then
    echo "DIST $DIST_NAME: PASS"
    exit 0
  fi
  echo "DIST $DIST_NAME: FAIL"
  exit 1
}
