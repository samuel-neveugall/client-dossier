# Phase 3: Protocol Skill & Hooks - Pattern Map

**Mapped:** 2026-10-10
**Files analyzed:** 22 (12 new code/test files, 10 doc amendments)
**Analogs found:** 19 / 22 (all analogs below are git-tracked; checked with `git ls-files`)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `hooks/hooks.json` | config | event-driven | RESEARCH "Code Examples / hooks.json" (no in-repo hooks config) + `.claude-plugin/plugin.json` (JSON style) | no in-repo analog |
| `hooks/session-start.py` | middleware (hook) | event-driven, stdin JSON -> stdout JSON | `scripts/lint.py` (`find_root`, header docstring, `main` + `__main__`) | role-match |
| `hooks/guard-sources.py` | middleware (hook) | event-driven, request-response (deny/allow) | `scripts/lint.py` (`find_root`, `LAYOUT_DIRS`/`_LAYOUT_DIRS_FOLDED` casefold) | role-match |
| `hooks/stop-check.py` | middleware (hook) | event-driven + subprocess git | `skills/dossier-init/scripts/init.py` `_is_git_repo`/`_git_tracked` (subprocess, fail-soft) + `lint.py` `find_root` | role-match |
| `skills/dossier/SKILL.md` | skill (judgement prose) | n/a | `skills/dossier-init/SKILL.md` + `templates/en/AGENTS-pointer.md` (content it must not contradict) | exact (form) |
| `tests/lib.sh` (optional `hooks_dir`, `run_hook`, `hook_json`) | test utility | transform | `tests/lib.sh` `init_py()` / `lint_py()` / `assert_lint()` | exact |
| `tests/test-hooks-config.sh` | test | file-I/O (read-only greps) | `tests/test-skill-shape.sh` | exact |
| `tests/test-hook-session-start.sh` | test | request-response (stdin->stdout) | `tests/test-init-pointer.sh` (scratch_repo + run script + assert_eq status) | role-match |
| `tests/test-hook-guard-sources.sh` | test | request-response | `tests/test-init-pointer.sh` / `tests/test-init-adopt.sh` | role-match |
| `tests/test-hook-stop.sh` | test | request-response + git state | `tests/test-init-adopt.sh` (fixture repo, git state) | role-match |
| `tests/test-skill-dossier.sh` | test | file-I/O (greps) | `tests/test-skill-shape.sh` | exact |
| `tests/scenarios/lib-scenario.sh` | test utility (harness) | batch (headless runs) | `tests/lib.sh` (sourced helper library) | partial |
| `tests/scenarios/fix-typo.sh` | test (behavioural, paid) | batch | `tests/fixtures/make-adopt-fixture.sh` (fixture builder) + `tests/run.sh` (summary line) | partial |
| `docs/superpowers/specs/2026-09-16-client-dossier-design.md` | doc amendment | n/a | RESEARCH "Spec and Doc Amendments" table (line refs) | n/a |
| `CLAUDE.md` | doc amendment | n/a | same table | n/a |
| `.planning/PROJECT.md`, `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, `.planning/STATE.md` | doc amendment | n/a | same table | n/a |
| `.gitignore` | config | n/a | existing `.gitignore` (section-comment style) | exact |

## Pattern Assignments

### `hooks/session-start.py`, `hooks/guard-sources.py`, `hooks/stop-check.py` (hook, event-driven)

**Analog:** `scripts/lint.py`

**Header pattern** (lint.py lines 1-25): shebang, module docstring stating tier, contract, Python target.
```python
#!/usr/bin/env python3
"""Lint a client-dossier repository.

Mechanics tier only (spec principle: "skills carry the judgement, scripts
carry the mechanics"). ...
It is read-only: it never writes, fixes, reformats, renames or deletes
anything, never prompts, ...
Python 3 standard library only, targeting Python >= 3.8.
"""
```
Hooks copy this shape: docstring names PROTO-0x / D-xx, states "read-only, fail open, exit 0", "Python 3 standard library only, targeting Python >= 3.8". Do NOT copy the `vibeflow:allow-large-file` comment (hooks stay small).

**Layout constants** (lint.py lines 64, 69, 81, 130-131) - hard-code identically:
```python
CONFIG_NAME = "dossier.yaml"
LIVING_DIR = "dossier"
OUTBOUND_DIR = "outbound"
LAYOUT_DIRS = frozenset(("sources", LIVING_DIR, "outbound", "knowledge"))
_LAYOUT_DIRS_FOLDED = frozenset(d.casefold() for d in LAYOUT_DIRS)
```
guard-sources uses the casefold idea: first component of `relpath(P, R)` `.casefold() == "sources"`.

**`find_root` - copy byte-identically** (lint.py lines 1163-1176; parity-tested by `tests/test-hooks-config.sh` with `sed -n '/^def find_root/,/^    return None$/p'`):
```python
def find_root(start):
    """The nearest directory at or above `start` holding dossier.yaml.

    No stop condition (D-01, Q-4): a dossier legitimately lives inside a
    larger repository, so the walk does not stop at `.git`. Returns None
    when no dossier.yaml exists anywhere up to the filesystem root.
    """
    here = Path(os.path.realpath(start))
    if not here.is_dir():
        here = here.parent
    for candidate in (here,) + tuple(here.parents):
        if os.path.isfile(os.path.join(str(candidate), CONFIG_NAME)):
            return str(candidate)
    return None
```
Requires `import os` and `from pathlib import Path`. guard-sources calls it on `dirname(target)`, not on session cwd.

**Entry point** - lint.py lines 2119-2130 uses `main()` + catch-all + `sys.exit(main())`:
```python
def main(argv=None):
    ...
    try:
        return _run(args.path)
    except Exception as exc:  # P-08: never masquerade as "this dossier has errors"
        print(...,file=sys.stderr)
        return EXIT_INTERNAL

if __name__ == "__main__":
    sys.exit(main())
```
DIVERGENCE for hooks: fail OPEN - catch-all must `pass` silently, no stderr, always exit 0 (RESEARCH "Hook skeleton (fail open)" lines 603-634; Anti-Patterns: exit 1 shows a notice in every repo). No argparse (input is stdin JSON).

**Output** - `json.dumps` only, single object on stdout:
- SessionStart: `{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "..."}}`
- PreToolUse deny: `{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "sources are immutable; file a correction in the dossier instead: <relpath>"}}` (message first, verbatim, for greps)
- Stop: `return` early if `data.get("stop_hook_active")`; else `{"decision": "block", "reason": ...}`. `status_sentence()` appends the dossier-status sentence only if `os.path.isfile(os.path.join(os.environ.get("CLAUDE_PLUGIN_ROOT",""), "skills/dossier-status/SKILL.md"))` (P-02; isolated function).

### `hooks/stop-check.py` - git subprocess

**Analog:** `skills/dossier-init/scripts/init.py` lines 555-582
```python
    try:
        result = subprocess.run(
            ["git", "-C", root, "rev-parse", "--is-inside-work-tree"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except (FileNotFoundError, OSError):
        return False
    return result.returncode == 0 and result.stdout.strip() == b"true"
```
Copy: argument list, `shell=False`, `stdout/stderr=PIPE` (3.8-safe; no `capture_output` needed though it is 3.7+), `FileNotFoundError` -> silent, non-zero rc -> silent, `--` before paths. Commands to run: `git --no-optional-locks -C R rev-parse --show-prefix` and `git --no-optional-locks -C R status --porcelain=v1 -z --untracked-files=normal -- .`; strip the prefix; for `R`/`C` consume the next NUL field (RESEARCH Pattern 3).

### `hooks/hooks.json` (config)

**No in-repo analog.** Use RESEARCH lines 551-566 verbatim (top-level `description` + `hooks`; shell form `python3 \"${CLAUDE_PLUGIN_ROOT}/hooks/<x>.py\"`; matcher `Write|Edit|MultiEdit|NotebookEdit|Bash`; timeouts 10/10/15). JSON indentation style: 2 spaces as in `.claude-plugin/plugin.json`.

### `skills/dossier/SKILL.md` (skill)

**Analog:** `skills/dossier-init/SKILL.md` lines 1-30
```markdown
---
name: dossier-init
description: Use when someone wants to start or set up a dossier for a client, partner, prospect or recruiter in this repository, or when ... 
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/init.py *)
---

# dossier-init

<one paragraph: what it does>
...
## What it produces
- `dossier.yaml` — ...
```
Copy: frontmatter with `name: dossier` (folder name matches), one-line `description:` starting "Use when", situations only, <= 1024 chars (stricter than the 1536 that test-skill-shape checks). No `allowed-tools`. `# dossier` H1, `##` sections, backticked fixed names, em-dash list items. Body < 500 lines. Plugin-level paths as `${CLAUDE_PLUGIN_ROOT}/scripts/lint.py`, never relative.

**Content consistency source:** `skills/dossier-init/templates/en/AGENTS-pointer.md` (whole file, 22 lines) - "Read before acting: `dossier/` and `knowledge/CONTEXT.md`. Update before handing back: whichever living files the work touched." and "Never: edit anything under `sources/`, send anything, or name a confidential party in `outbound/`." The skill expands, never contradicts.
**Layout list source:** `skills/dossier-init/scripts/init.py` `FOLDERS` lines 29-42 (twelve dirs) and `lint.py` `LIVING_FILES` lines 70-78 (seven files).
**Body checklist:** RESEARCH Pattern 4 items 1-11.

Constraint (Pitfall 6): if `skills/dossier-init/SKILL.md` is touched, `tests/test-skill-shape.sh` lines 73-77 forbid `stop hook|lint\.py|hooks\.json|marketplace\.json|commands/|sessionstart|pretooluse|session-event` in it.

### `tests/test-skill-dossier.sh` and `tests/test-hooks-config.sh` (test, greps)

**Analog:** `tests/test-skill-shape.sh` (whole file, 79 lines)

Header + source (lines 1-13):
```bash
#!/usr/bin/env bash
# tests/test-skill-shape.sh — mechanical checks on skills/dossier-init/SKILL.md
# (SCAF-06/SCAF-07, plan 01-06). ...
set -u

# shellcheck source=./lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
```
Frontmatter + description length (lines 21-30) - change bound to 1024:
```bash
assert_grep_e '^name: dossier-init$' "$SKILL_MD"
assert_eq 'dossier-init' "$SKILL_DIR_NAME" 'the containing folder is named dossier-init, matching name:'
DESC_LEN=$(sed -n 's/^description: //p' "$SKILL_MD" | head -1 | tr -d '\n' | wc -c | tr -d ' ')
if [ "$DESC_LEN" -gt 0 ] && [ "$DESC_LEN" -le 1536 ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "FAIL: description: length $DESC_LEN is not in (0, 1536]" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
```
Loop of required terms (lines 53-62):
```bash
for leaf in 'sources/received' 'sources/transcripts/raw' ...; do
  assert_grep "$leaf" "$SKILL_MD"
done
```
Count-based negative (lines 73-74) -> reuse for the self-updating pointer check: for each `skills/<x>/SKILL.md` with x != dossier assert named; for absent `dossier-ingest|draft|call|status` assert `grep -c` == 0.
End with `finish`.

test-hooks-config.sh extras (no in-repo analog for these lines): `python3 -c 'import json,sys; json.load(open(sys.argv[1]))'`; `python3 -c 'import ast,sys; ast.parse(open(sys.argv[1]).read(), feature_version=(3,8))' "$f"` per `hooks/*.py`; find_root parity via `assert_eq "$(sed -n '/^def find_root/,/^    return None$/p' "$(lint_py)")" "$(sed -n ... "$hook")" '...'`; `command -v claude` else `skip 'claude CLI absent'` (lib.sh `skip`, line 23).

### `tests/test-hook-session-start.sh`, `tests/test-hook-guard-sources.sh`, `tests/test-hook-stop.sh` (test, stdin->stdout)

**Analog:** `tests/test-init-pointer.sh` lines 1-40 (scratch repo, real init.py, capture status with `|| status=$?`, `--- Case X ---` blocks)
```bash
# --- Case A: neither instructions file exists ---
dA=$(scratch_repo)
statusA=0
python3 "$(init_py)" \
  --target "$dA" \
  --language en \
  --counterpart 'Acme Consulting|ordering party|Jane Doe' \
  >"$dA.stdout" 2>"$dA.stderr" || statusA=$?
assert_eq 0 "$statusA" 'Case A: init exits 0 on a repo with no instructions files'
```
Fixture = `scratch_repo` + `init.py` (fixtures generated, never committed - Phase 2 D-28/D-29). Hook invocation and JSON building: RESEARCH lines 649-663 (`hook_json` via `python3 -c json.dumps` with argv, never `printf`; parse decision with python3, "none" on empty stdout). Write outputs beside `$d` (`"$d.out"`) like `"$dA.stdout"`, never inside the dossier (Stop test depends on clean git state).
Stop test additionally: commit the scaffold (`git -C "$d" add -A && git -C "$d" commit -qm init`) like `test-init-adopt.sh` snapshot pattern, then mutate `outbound/`/`sources/`/`dossier/`; `PATH=/nonexistent` case for "git missing"; temp `CLAUDE_PLUGIN_ROOT` dir with/without `skills/dossier-status/SKILL.md` (P-02).

### `tests/lib.sh` (optional helpers)

**Analog:** itself, lines 33-46:
```bash
# lint_py — the absolute path to the linter under test. Mirrors init_py():
# the bash harness has no ${CLAUDE_PLUGIN_ROOT} expansion, and a hardcoded
# path breaks the moment the repository is checked out elsewhere.
lint_py() {
  echo "$REPO_ROOT/scripts/lint.py"
}
```
Add `hooks_dir() { echo "$REPO_ROOT/hooks"; }`, and a `run_hook HOOK` that mirrors `assert_lint` (lines 135-142: stderr to `mktemp`, stdout into a global like `LINT_OUT` -> `HOOK_OUT`, status captured with `|| status=$?`). Initialise any new global at top (lines 28-31 comment: `set -u` aborts on read before first set). Bash 3.2 safe (`case` globs, no `[[ =~ ]]` captures, no associative arrays).

### `tests/scenarios/lib-scenario.sh`, `tests/scenarios/fix-typo.sh` (harness, batch)

**Partial analogs:** `tests/lib.sh` (sourced library + `REPO_ROOT` resolution line 8: `REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"` -> from `tests/scenarios/` use `/../..`); `tests/run.sh` (one summary line, exit 1 on failure, lines 25-30); `scratch_repo` (lines 49-56) for the fixture, but under `mktemp -d` outside `~/Documents/dev`.
Functions: `build_dossier`, `strip_agents_pointer` (P-01, single clearly marked function, called from fix-typo.sh only), `run_variant`, `verdict`. Invocation flags verbatim from RESEARCH lines 441-452; GREEN/RED/INCOMPLETE rules RESEARCH line 476; D-12 assert on `system/init.skills` containing `client-dossier:dossier` (harness error, not a verdict); `is_error: true` -> harness error. Output dir = `$1` or `mktemp -d` (D-11). Not named `test-*.sh` and lives in a subdir so `tests/run.sh` line 11 never globs it.

### `.gitignore`
**Analog:** itself - comment-headed sections. Only add an entry if the scenario evidence or scratch outputs could land in the tree (e.g. none needed if output dir is `mktemp -d`); keep `.planning/phases/03-*/evidence/` tracked (D-11).

### Doc amendments (spec, CLAUDE.md, PROJECT, REQUIREMENTS, ROADMAP, STATE)
No code analog; use RESEARCH "Spec and Doc Amendments This Phase Must Carry" (lines 681-702) as the exact edit list with line numbers. CLAUDE.md Commands section: add entries in the existing style (`` - `bash tests/test-lint.sh` — the lint tests alone. ``).

## Shared Patterns

### Fail-open, silent hooks
**Source:** RESEARCH lines 603-634 (diverges deliberately from lint.py's exit-3 internal error)
**Apply to:** all three `hooks/*.py`. `try: main() except Exception: pass; sys.exit(0)`; stdout is only the JSON object; no stderr chatter.

### Dossier-root discovery
**Source:** `scripts/lint.py` lines 1163-1176 (`find_root`), byte-identical copy
**Apply to:** all three hooks; parity asserted in `tests/test-hooks-config.sh`; the skill states the same rule in prose (nearest wins, no stop at `.git`).

### Python 3.8 stdlib discipline
**Source:** lint.py / init.py docstrings ("Python 3 standard library only, targeting Python >= 3.8")
**Apply to:** hooks. Avoid `Path.is_relative_to`, `str.removeprefix`, `realpath(strict=)`, `list[str]` annotations, `functools.cache`. Use `os.path.relpath` + split on `os.sep`.

### Subprocess safety
**Source:** `skills/dossier-init/scripts/init.py` lines 557-582
**Apply to:** `stop-check.py`. Argument list, no shell, `--` before paths, `FileNotFoundError/OSError` -> treat as "not applicable".

### Test file skeleton
**Source:** `tests/test-skill-shape.sh` lines 1-13 and 79; `tests/lib.sh` assertions
**Apply to:** every new `tests/test-*.sh`. Header comment naming requirement IDs and decisions, `set -u`, `source .../lib.sh`, `--- Case ---` sections, `finish`. No framework; JSON via `python3 -c`; `skip` for environment gaps.

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `hooks/hooks.json` | config | event-driven | No hooks exist yet; use RESEARCH Code Examples (verified by probe) |
| Bash tokenizer in `guard-sources.py` | utility | transform | No shell parsing in repo (init.py imports `shlex` only for quoting); use RESEARCH Pattern 2 tables (`shlex.shlex(posix=True, punctuation_chars=True)`, `whitespace_split=True`) |
| `tests/scenarios/*` headless `claude -p` driving | harness | batch | No paid/behavioural harness exists; use RESEARCH Pattern 5 |

## Metadata

**Analog search scope:** `scripts/`, `skills/dossier-init/`, `tests/`, `.claude-plugin/`, `.gitignore`
**Files scanned:** 14
**Pattern extraction date:** 2026-10-10
