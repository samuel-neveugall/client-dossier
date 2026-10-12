# Phase 7: Manifests, Docs & Distribution - Pattern Map

**Mapped:** 2026-10-11
**Files analyzed:** 27 (new or modified)
**Analogs found:** 22 / 27 (the rest are documents or JSON with RESEARCH-provided shapes)

All analog paths below are git-tracked source (checked with `git ls-files`).

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `.claude-plugin/plugin.json` (modify) | config | static | itself (3 keys today) + RESEARCH Pattern 1 | exact |
| `.claude-plugin/marketplace.json` | config | static | RESEARCH Pattern 1 JSON | no code analog |
| `.codex-plugin/plugin.json` | config | static | `.claude-plugin/plugin.json` + RESEARCH Pattern 2 | role-match |
| `.agents/plugins/marketplace.json` | config | static | RESEARCH Pattern 2 JSON | no code analog |
| `commands/dossier-lint.md` | command (prompt) | request-response | `skills/dossier-status/SKILL.md` lines 31-37 (guarded script call, single-quoted placeholder) | role-match |
| `evals/routing/<case>/{prompt.md,case.yaml,graders/*.md}` | test data (paid) | batch | RESEARCH Pattern 5 (proven case) | no code analog |
| `evals/routing/<case>/scaffold.sh` | test fixture | file-I/O | `tests/scenarios/lib-scenario.sh` `build_dossier()` (line 60) | role-match |
| `scripts/release.sh` | utility (maintainer CLI) | file-I/O + git | `tests/test-hooks-config.sh` lines 30-44 (python3 heredoc with argv) + RESEARCH Pattern 6 | partial |
| `README.md`, `LICENSE`, `CHANGELOG.md` | docs | static | RESEARCH Pattern 7 checklist | no code analog |
| `tests/test-manifests.sh` | test | static + CLI | `tests/test-hooks-config.sh` | exact |
| `tests/test-commands.sh` | test | static | `tests/test-skill-shape.sh` | exact |
| `tests/test-release.sh` | test | scratch git | `tests/lib.sh` `scratch_repo` + `tests/test-ingest-fetch.sh` (label/expected/actual lines) | role-match |
| `tests/test-readme.sh` | test | static grep | `tests/test-skill-shape.sh` lines 62-87 | exact |
| `tests/test-evals-shape.sh` | test | static | `tests/test-skill-shape.sh` lines 41-48 (loop over globbed files) + `test-hooks-config.sh` python parse | exact |
| `tests/test-skill-shape.sh` (extend, DIST-03 guard check) | test | static | itself | exact |
| `tests/dist/install-claude.sh` | test (out of run.sh) | CLI, isolated | `tests/scenarios/fix-typo.sh` + `lib-scenario.sh` (`scenario_die`, `scenario_preflight`, `scrub_check`) | role-match |
| `tests/dist/install-codex.sh` | same | same | same | role-match |
| `tests/dist/install-skills.sh` | same | same (networked npm) | same | role-match |
| `.gitignore` (add `evals/results/`) | config | static | existing `.gitignore` sections | exact |
| `CLAUDE.md` (commands list, D-03 warning count, DIST-04 amendment) | docs | static | its own "Commands" section | exact |
| `docs/superpowers/specs/2026-09-16-client-dossier-design.md` §4/§8 | docs | static | itself | exact |
| `.planning/REQUIREMENTS.md` DIST-04 | docs | static | itself | exact |
| `.planning/STATE.md` (pre-publication checklist D-12, D-13) | docs | static | itself | exact |
| `skills/dossier-init/SKILL.md` (D-15 quoting) | skill | static | `skills/dossier-status/SKILL.md` 31-37, `skills/dossier-ingest/SKILL.md` 31, 56 | exact |
| `hooks/guard-sources.py` (optional apply_patch branch) | hook | event-driven | itself, `main()` lines 1269-1295 | exact |
| `tests/test-hook-guard-sources.sh` (optional new cases) | test | event-driven | itself, `expect_deny`/`expect_silent` lines 45-75 | exact |

## Pattern Assignments

### `tests/test-*.sh` (all new free tests)

**Analog:** `tests/lib.sh` (248 lines) and `tests/test-skill-shape.sh`.

**Header and sourcing** (`tests/test-skill-shape.sh` lines 1-13): leading comment block naming the requirement IDs and plan, then:
```bash
set -u

# shellcheck source=./lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
```
`set -u` only, never `set -e` (lib.sh lines 4-6: a failed assertion must not abort). End every file with `finish`. `tests/run.sh` globs `tests/test-*.sh`; no registration needed (run.sh lines 11-23). Note run.sh treats nonzero exit as FAIL, so `skip` (not fail) when an optional CLI is missing.

**lib.sh helpers available** (exact signatures):
- `REPO_ROOT` (line 8), `lint_py`, `init_py`, `hooks_dir` (lines 44-59)
- `scratch_repo` (113-121): `mktemp -d`, `git init -q`, sets `user.email test@example.invalid`, `user.name "Test Runner"`; echoes path
- `assert_file PATH`, `assert_dir PATH`, `assert_exec PATH`
- `assert_grep BRE PATH`, `assert_grep_e ERE PATH`, `assert_not_grep BRE PATH` (all use `grep -q --`)
- `assert_eq EXPECTED ACTUAL LABEL`
- `skip LABEL` (23-26) for "claude/codex not on PATH"; counted, never fails
- `run_hook NAME JSON` / `hook_field DOTTED.PATH` / `hook_json ...` (hook tests only)
- `finish` (238-248)

**Manual pass/fail idiom** when no helper fits (test-skill-shape.sh 25-30):
```bash
if [ "$DESC_LEN" -gt 0 ] && [ "$DESC_LEN" -le 1536 ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "FAIL: description: length $DESC_LEN is not in (0, 1536]" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
```

**Bash 3.2 constraints:** no arrays (test-ingest-fetch.sh line 18 says "bash 3.2, no arrays"), space-separated word lists iterated with `for x in $LIST` (test-hooks-config.sh line 16, 46), `case` glob matching instead of `[[ =~ ]]` (lib.sh 212-221). Note: RESEARCH Pattern 6's `"${files[@]}"` in release.sh uses an array; release.sh is not a test but keep it bash-3.2 compatible, so pass the pathspec list literally (four fixed paths) instead of an array.

### `tests/test-manifests.sh` (DIST-01/02)

**Analog:** `tests/test-hooks-config.sh`.

**JSON parse + field extraction via python3 heredoc with argv** (lines 22-44):
```bash
PARSE_STATUS=0
python3 -c 'import json, sys; json.load(open(sys.argv[1]))' "$HOOKS_JSON" 2>/dev/null || PARSE_STATUS=$?
assert_eq 0 "$PARSE_STATUS" 'hooks.json is valid JSON'

DECLARED="$(python3 - "$HOOKS_JSON" <<'PY' 2>/dev/null
import json, sys
data = json.load(open(sys.argv[1]))
...print("\t".join([...]))
PY
)"
```
then iterate with `while IFS=$'\t' read -r a b c; do ... assert_eq ...; done` (line 56). Use the same shape to print `label<TAB>expected<TAB>actual` lines for each manifest field (author.name, license, no `version` on entries, codex/claude identity equality, byte-equality with `json.dumps(indent=2)+"\n"`).

**CLI section:** `command -v claude >/dev/null 2>&1 || skip 'claude not on PATH: validate not run'`; otherwise `claude plugin validate .` exit 0, `--strict` exit 1 (D-03). Use status capture `X=0; cmd || X=$?` as above.

### `tests/test-commands.sh` (DIST-04)

**Analog:** `tests/test-skill-shape.sh` lines 41-48 (R4-M4 loop):
```bash
for skill_file in "$REPO_ROOT"/skills/*/SKILL.md; do
  if grep -qE '^allowed-tools:' "$skill_file"; then
    echo "FAIL: ... carries allowed-tools in its frontmatter (R4-M4)" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  else
    TESTS_PASSED=$((TESTS_PASSED + 1))
  fi
done
```
Apply to `commands/*.md`; add collision loop: `stem=$(basename "$f" .md); [ -d "$REPO_ROOT/skills/$stem" ]` -> FAIL. Expected set as a space-separated string (`EXPECTED_COMMANDS='dossier-lint'`, reversion path P-01(b) edits only this line). Body greps: `assert_grep 'python3 "${CLAUDE_PLUGIN_ROOT}/scripts/lint.py"'` and a single-quoted placeholder `'<path>'`.

### `tests/test-readme.sh` (DIST-05)

**Analog:** `tests/test-skill-shape.sh` lines 63-72 (loop of `assert_grep` over required phrases) and 79-87 (count-based `grep -ci` + `assert_eq`). Phrase list from RESEARCH Validation row DIST-05 (install commands, "loses", Bash guard limits, semver/CHANGELOG/tag, MIT, `/hooks`). LICENSE: `assert_grep 'MIT License'`, `assert_grep 'Samuel Neveu'`; CHANGELOG: `assert_grep '^## \[Unreleased\]'` and `assert_not_grep '^## \[[0-9]'` (D-16).

### `tests/test-evals-shape.sh` (DIST-06)

**Analog:** test-skill-shape.sh loop + test-hooks-config.sh python heredoc. Find case dirs with `find "$REPO_ROOT/evals" -name prompt.md` piped to `while read -r`; parse frontmatter in python3 (argv path), check keys against an allowed set, `graders/*.md` count >= 1, each `tool_used` grader's skill name maps to an existing `skills/<name>/`. `assert_exec` on each `scaffold.sh`, `assert_grep '^set -eu' scaffold.sh`, `assert_grep '^evals/results/' "$REPO_ROOT/.gitignore"`.

### `tests/test-release.sh` (DIST-07)

**Analog:** `scratch_repo` (lib.sh 113-121) + label/expected/actual pattern of `test-ingest-fetch.sh` (lines 14-18 header explain the approach).
- Build: `d=$(scratch_repo)`; copy real `.claude-plugin/`, `.codex-plugin/`, `.agents/`, `CHANGELOG.md`, `scripts/release.sh` into `$d`; commit; add a bare `origin` (`git init -q --bare "$(mktemp -d)"`).
- Each refusal: `S=0; (cd "$d" && bash scripts/release.sh '1.0.0; touch PWNED') >/dev/null 2>&1 || S=$?; assert_eq 1 "$S" ...`; then `[ ! -e "$d/PWNED" ]`, `git -C "$d" tag -l | wc -l` unchanged, `git status --porcelain` empty.
- Success: `assert_eq tag "$(git -C "$d" cat-file -t v1.0.0)"`, `assert_grep_e '^## \[1\.0\.0\] - [0-9]{4}-' CHANGELOG.md`, `git ls-remote --tags origin` empty.

### `tests/dist/install-{claude,codex,skills}.sh` (outside run.sh)

**Analog:** `tests/scenarios/fix-typo.sh` (header lines 1-34) and `tests/scenarios/lib-scenario.sh`.
- Header documents: what it checks, exit codes (`0 pass, 1 gate not met, 2 harness error`), usage, "never run by tests/run.sh". Directory `tests/dist/` is not globbed by run.sh (only `tests/test-*.sh`).
- Harness error helper (lib-scenario.sh 23-26):
```bash
scenario_die() {
  echo "HARNESS ERROR: $1" >&2
  exit 2
}
```
- Preflight (lib-scenario.sh 31-48): `command -v "$BIN"` and `case "$help" in *"$flag"*) ;; *) scenario_die ...` for each subcommand used (`plugin marketplace add`, `plugin install`, `plugin details`; codex `plugin add`, `debug prompt-input`).
- Isolation (D-17): `cfg=$(mktemp -d); h=$(mktemp -d); clone=$(mktemp -d)/repo; git clone -q "$REPO_ROOT" "$clone"`; every call prefixed `CLAUDE_CONFIG_DIR="$cfg" HOME="$h"` / `CODEX_HOME="$ch" HOME="$h"`. Exact commands in RESEARCH Pattern 1/2.
- Evidence: before copying logs under `.planning/phases/07-.../evidence/`, call `scrub_check FILE...` (lib-scenario.sh 588-608: fails on `sk-ant-` or git user email, warns on `/Users/`). Either source `../scenarios/lib-scenario.sh` or a tiny `tests/dist/lib-dist.sh` that copies `scenario_die` + `scrub_check` verbatim (sourcing lib-scenario.sh also pulls `SCENARIO_CLAUDE` defaults; acceptable).
- `install-skills.sh`: `DISABLE_TELEMETRY=1 DO_NOT_TRACK=1 npm exec --yes --package=skills@1.7.2 -- skills add "$clone" --skill '*' --agent claude-code codex cursor --copy -y` (not `npx -y`, rtk rewrite issue). Human-verify checkpoint before first run (SUS verdict).

### `scripts/release.sh`

**Analog:** no shell script under `scripts/` (only `lint.py`). Conventions to copy:
- Python embedded via `python3 - "$arg" <<'PY'` with quoted heredoc delimiter and value through `sys.argv` (test-hooks-config.sh 30-44); never interpolate `$version` into code (RESEARCH Pattern 6).
- Executable bit (`scripts/lint.py` is `-rwxr-xr-x`), `#!/usr/bin/env bash`, header comment, `set -euo pipefail`, `die() { echo "release: $1" >&2; exit 1; }` (mirror `scenario_die` style, exit 1 for refusal).
- Commit by explicit pathspec (`git commit -- .claude-plugin/plugin.json .codex-plugin/plugin.json .claude-plugin/marketplace.json .agents/plugins/marketplace.json CHANGELOG.md`), never `git add -A`; `git tag -a "v$version"`; no `git push` anywhere (test greps for it).
- JSON write: `json.dump(indent=2, ensure_ascii=False)` + `"\n"` so test-manifests' byte-equality check stays green after a bump.

### `commands/dossier-lint.md`

**Analog:** `skills/dossier-status/SKILL.md` lines 31-37:
```
test -x "${CLAUDE_SKILL_DIR}/scripts/status.py"
...
"${CLAUDE_SKILL_DIR}/scripts/status.py" '<root>'
```
Same shape with `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/lint.py" '<path>'`; refuse a value with `'` or newline (A4-F1). Frontmatter: `description` + `argument-hint`, no `allowed-tools`. Full body in RESEARCH Pattern 4. Exit codes quoted verbatim from CLAUDE.md "Commands".

### `evals/routing/<case>/scaffold.sh`

**Analog:** `tests/scenarios/lib-scenario.sh` `build_dossier()` (line 60+) which runs the real `init.py`. Body from RESEARCH Pattern 5 (`set -eu`, `here`/`root` via `BASH_SOURCE`, `init.py --target . --language en --counterpart 'Jane Doe|Head of IT|jane@example.com' --confidential-name 'Globex'`, commit with `-c user.email=eval@example.invalid`). Must be `chmod +x`.

### `skills/dossier-init/SKILL.md` (D-15)

**Current** (lines 70 and 114):
```
${CLAUDE_SKILL_DIR}/scripts/init.py --target <dossier root> --propose-renames
${CLAUDE_SKILL_DIR}/scripts/init.py \
```
**Target, as in dossier-ingest (31, 56) and dossier-status (31, 37):** `"${CLAUDE_SKILL_DIR}/scripts/init.py"` with single-quoted placeholders (`'<dossier root>'`). Re-run `tests/test-skill-shape.sh` (lines 51-60 count `CLAUDE_SKILL_DIR` >= 2 and forbid a repo-relative path), `test-init-*.sh`. Note test-skill-shape.sh line 83 forbids `lint.py|hooks.json|marketplace.json|commands/` in this SKILL.md: do not add such text here.

### `hooks/guard-sources.py` (optional apply_patch branch)

**Analog:** itself, `main()` lines 1269-1295:
```python
if tool in WRITE_TOOLS:
    path = tool_input.get("file_path") or tool_input.get("notebook_path")
    if isinstance(path, str) and path:
        hit = sources_target(path, cwd)
elif tool == "Bash":
    command = tool_input.get("command")
    if isinstance(command, str) and command:
        hit = bash_hit(command, cwd)
        note = " (heuristic guard: ...)"
```
Add `elif tool == "apply_patch":` parsing `*** Add File: / Update File: / Delete File: / Move to:` lines from `tool_input["command"]`, each through `sources_target(path, cwd)`. Keep the fail-open `except Exception` at module bottom and the deny JSON shape unchanged. Do not touch `WRITE_TOOLS` (line 43) nor the hooks.json matcher (`test-hooks-config.sh` line 17 asserts it exactly). Tests: add cases with `expect_deny LABEL "$(hook_json PreToolUse "$d" apply_patch command "$patch")" 'sources/...'` and `expect_silent` (test-hook-guard-sources.sh 45-75).

### `.gitignore`

Existing style: a comment line per section, then patterns. Append:
```
# claude plugin eval run artefacts (recorded copies live under .planning/.../evidence/)
evals/results/
```

### `CLAUDE.md`, spec §4/§8, REQUIREMENTS DIST-04

Edit in place in the same commit (spec wins rule). CLAUDE.md "Commands" currently says validate has "two known warnings"; change to one (root CLAUDE.md) and add the new test commands (`test-manifests.sh`, `test-commands.sh`, `test-release.sh`, `test-readme.sh`, `test-evals-shape.sh`, `tests/dist/*.sh`, `claude plugin eval ...`, `scripts/release.sh`). Keep P-01 amendment wording isolated in the commands plan.

## Shared Patterns

### Test harness (all `tests/test-*.sh`)
Source: `tests/lib.sh`. `set -u`, source lib.sh, assertions, `finish`. Optional CLIs -> `skip`. No arrays. Python only through `python3 -c '...' "$arg"` or `python3 - "$arg" <<'PY'`.

### Paid / CLI-dependent scripts outside run.sh
Source: `tests/scenarios/lib-scenario.sh` (`scenario_die`, `scenario_preflight`, `scrub_check`). Exit 0/1/2 convention, `mktemp -d` everything, evidence scrubbed before commit.

### Quoting of script calls in prose (A4-F1, D-15)
Source: `skills/dossier-status/SKILL.md` 31-37. Double-quoted `"${VAR}/path"`, single-quoted placeholders, `test -x`/`test -f` guard before use, stated fallback.

### No `allowed-tools` (R4-M4)
Source: `tests/test-skill-shape.sh` 41-48; extend to `commands/*.md`.

## No Analog Found

| File | Role | Reason |
|---|---|---|
| `.claude-plugin/marketplace.json` | config | first marketplace; use RESEARCH Pattern 1 |
| `.agents/plugins/marketplace.json` | config | use RESEARCH Pattern 2 |
| `evals/**/prompt.md`, `case.yaml`, `graders/*.md` | eval data | use RESEARCH Pattern 5 |
| `README.md`, `LICENSE`, `CHANGELOG.md` | docs | use RESEARCH Pattern 7 |
| `scripts/release.sh` (core logic) | utility | only conventions borrowed; logic from RESEARCH Pattern 6 |

## Metadata

**Analog search scope:** `tests/`, `tests/scenarios/`, `scripts/`, `hooks/`, `skills/*/SKILL.md`, `.claude-plugin/`, `.gitignore`
**Files scanned:** ~15
**Pattern extraction date:** 2026-10-11
