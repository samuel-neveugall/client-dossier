# Phase 2: Linter & Test Harness - Pattern Map

**Mapped:** 2026-09-17
**Files analyzed:** 7 (4 new, 3 modified)
**Analogs found:** 7 / 7 (5 exact, 2 role-match)

Every analog path below was verified git-tracked with `git ls-files` (no install mirror, no
gitignored path). The repository has exactly two source tiers today — one Python script
(`skills/dossier-init/scripts/init.py`) and one bash test harness (`tests/`) — so the house
style is small, uniform and fully readable; quote it rather than inventing.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `scripts/lint.py` (NEW) | utility / CLI script (mechanics tier) | file-I/O read-only → transform → stdout report | `skills/dossier-init/scripts/init.py` | exact role (only Python in repo), inverse flow (producer vs consumer) |
| `tests/test-lint.sh` (NEW) | test | batch / subprocess-and-assert | `tests/test-init-adopt.sh` (fixture-driven) + `tests/test-init-empty.sh` (exit-code cases) | exact |
| `tests/fixtures/make-lint-fixtures.sh` (NEW) | test fixture generator | file-I/O (write to `mktemp -d`, echo path) | `tests/fixtures/make-adopt-fixture.sh` | exact |
| `tests/fixtures/lint/fr/` (NEW) | test data (static tree) | static content read by the linter | `skills/dossier-init/templates/fr/*.md` (content shape) + `tests/test-init-fr.sh` (how French content is asserted) | role-match |
| `tests/lib.sh` (MODIFIED, additive) | test utility | — | itself, `tests/lib.sh:13-19` (`init_py`) and `:31-102` (assertions) | exact (extend in place) |
| `skills/dossier-init/scripts/init.py` (MODIFIED, surgical) | utility / CLI script | file-I/O write | itself, `init.py:193-223` (`_SAFE_PLAIN_SCALAR_RE` + `emit_scalar`) | exact (edit in place) |
| `tests/test-init-empty.sh` (MODIFIED, +2 assertions) | test | subprocess-and-assert | itself, `tests/test-init-empty.sh:262-283` (the `--language` quoting cases) | exact |

## Pattern Assignments

### `scripts/lint.py` (utility / CLI script, read-only file-I/O → report)

**Analog:** `skills/dossier-init/scripts/init.py` — the only existing Python file. Mirror its
header, its constants block, its `build_parser()` / `main(argv=None)` split and its comment
doctrine. Note it is the *producer* of what `lint.py` consumes, so the two files are a
contract pair; `lint.py` is a new file, not a copy.

**Header pattern** (`init.py:1-26`) — shebang, the large-file marker with a reason, a module
docstring that names the tier and the Python floor, then stdlib imports only:

```python
#!/usr/bin/env python3
# vibeflow:allow-large-file -- mechanics-tier scaffold script; grew past the
# 300-line guard when plan 01-02 wired the eleven remaining templates and
# resolve_template_dir(). Splitting deferred: ...
"""Scaffold a client-dossier repository.

Mechanics tier only (spec principle: "skills carry the judgement, scripts
carry the mechanics"). Every input arrives as a command-line argument -- this
script never prompts, never reads a TTY, and never shells out. Judgement
(...) lives in skills/dossier-init/SKILL.md.

Python 3 standard library only, targeting Python >= 3.8.
"""

import argparse
import datetime
import os
import re
import shlex
import subprocess
import sys
from pathlib import Path
```

Copy the four moving parts: (1) `#!/usr/bin/env python3` and commit the file mode `100755`
(`git ls-files -s skills/dossier-init/scripts/init.py` → `100755`); (2) a
`# vibeflow:allow-large-file -- <reason>` marker on line 2 if the file exceeds 300 lines
(RESEARCH Q-6 expects 400-500 lines, so plan for it deliberately and record the window);
(3) the docstring's closing line **verbatim**: `Python 3 standard library only, targeting
Python >= 3.8.` (P-14 forbids `str.removeprefix`, `Path.is_relative_to`, `match`, `X | Y`);
(4) plain `import x` / `from pathlib import Path`, no aliasing, no `__future__`.

**Module-level fixed-layout constants** (`init.py:27-56`) — literal tuples, each preceded by a
comment that cites the spec section *and* explains why, written in ASCII (`Sec3.2`, never `§`,
never a curly quote — the whole file is ASCII):

```python
# The twelve directories the scaffold creates (spec Sec3.2).
FOLDERS = (
    "sources",
    "sources/received",
    ...
)

# The seven leaves spec Sec3.2 names verbatim. Git does not track empty
# folders, so each gets a .gitkeep, written unconditionally (never "if
# empty") -- an adopted repository can hold a folder that is empty today but
# never survived a clone, ...
GITKEEP_LEAVES = (
    "sources/received",
    "sources/transcripts/raw",
    "knowledge/decisions",
    "knowledge/watch",
    "outbound/deliverables",
    "outbound/mails",
    "outbound/calls",
)
```

`lint.py`'s `LIVING_FILES`, `OUTBOUND_SUBS`, the protocol-keyword block and `LANGUAGE_WORDS`
take exactly this shape: tuples/frozensets of string literals, a `why` comment above each,
never derived from config (C-2). `LANGUAGE_WORDS` must sit in its own block with a comment
saying it is data and **not** a protocol-keyword table (D-19/C-3). The precedent for a
frozenset constant is `init.py:159` (`LIVING_FILE_HINT_NAMES = frozenset(...)`).

**Regex-constant pattern** (`init.py:78`, `:211`) — module-level, `_`-prefixed when private,
compiled once:

```python
_LAST_UPDATED_RE = re.compile(r"^(Last updated:[ \t]*)YYYY-MM-DD[ \t]*$", re....)
...
_SAFE_PLAIN_SCALAR_RE = re.compile(r"^[A-Za-z][A-Za-z0-9_-]*$")
```

**Docstring pattern for helpers** (`init.py:180-190`, `:291-297`) — one summary line, then the
*reason*, never a restatement of the code:

```python
def yaml_quote(value):
    """Return a double-quoted YAML scalar, safe for any user-supplied string.

    Strips every character below 0x20 (newlines included), then escapes
    backslashes and double quotes -- in that order, so a backslash inserted
    by the first escape is never re-escaped by the second.
    """


def under_root(root, path):
    """True when the resolved `path` is `root` or lives under it."""
    resolved_root = os.path.realpath(root)
    resolved_path = os.path.realpath(path)
    return os.path.commonpath([resolved_root, resolved_path]) == resolved_root
```

`under_root()` is the idiom to reuse for any containment check in `lint.py` (root discovery,
sub-dossier boundary). Note `--` is used instead of an em dash everywhere (ASCII rule).

**CLI pattern** (`init.py:689-732`) — a `build_parser()` function returning the parser, with
per-argument `help=`, `choices=` wherever the value set is closed:

```python
def build_parser():
    parser = argparse.ArgumentParser(
        description="Scaffold a client-dossier repository (mechanics tier; never interactive)."
    )
    parser.add_argument("--target", default=".", help="Path to the repository to scaffold.")
    ...
    parser.add_argument("--status-header", default="required", choices=["required"])
    return parser
```

`lint.py` takes a single optional positional (`parser.add_argument("path", nargs="?",
default=".", help=...)`, D-01). Keep the `description=` one-liner in the same voice.

**Entry-point + error-handling + exit-code pattern** (`init.py:735-737`, `:740-744`, and the
file's last two lines) — `main()` *returns* an int, never calls `sys.exit()` mid-body; errors
print `error: ...` to stderr and return:

```python
def main(argv=None):
    args = build_parser().parse_args(argv)

    target_root = os.path.realpath(args.target)
    if not os.path.isdir(target_root):
        print("error: --target {!r} is not a directory".format(args.target), file=sys.stderr)
        return 1
    ...
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

Copy this exactly — it is what makes D-02's three-code contract implementable: `return 2` for
"no dossier.yaml found from <path> upward" on stderr, `return 1` when any ERROR/C1 finding
exists, `return 0` otherwise, and (P-08) a `try/except Exception` around the body of `main()`
returning a distinct code so an uncaught exception never masquerades as exit 1.

**String formatting:** `"{}: {}".format(...)` / `"{!r}"`, never f-strings — `init.py` uses
`.format()` in every one of its ~30 output lines (`:223`, `:255-279`, `:741`). Match it.

**Report-printing pattern** (`init.py` tail) — bare `print()` of `label: value` lines, then a
single summary line:

```python
    print("pointer: {} CLAUDE.md".format(claude_result))
    ...
    print("done: {} created, {} kept".format(created_count, kept_count))
```

D-04's finding line (`<path>:<line>: ERROR [E4] <message>`) and the closing
`N error(s), M warning(s)` are the same shape: one `print()` per line, summary last.

---

### `tests/test-lint.sh` (test, subprocess-and-assert)

**Analog:** `tests/test-init-adopt.sh` (fixture-generator-driven, 87 lines) and
`tests/test-init-empty.sh` (multi-case exit-code assertions, 311 lines).

**Preamble pattern — copy verbatim, only the header prose changes** (`test-init-adopt.sh:1-14`):

```bash
#!/usr/bin/env bash
# tests/test-init-adopt.sh — SCAF-06 / D-14/D-15/D-17: `--propose-renames`
# detects an existing repository's folders and files that already play a
# dossier role under other names, ... — writing nothing.
#
# Fails now: `--propose-renames` does not exist yet (RED gate for Task 2).
set -u

# shellcheck source=./lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

FIXTURE_SCRIPT="$(dirname "${BASH_SOURCE[0]}")/fixtures/make-adopt-fixture.sh"
GOLDEN="$REPO_ROOT/tests/golden/adopt-proposal.txt"
```

Exact invariants: `#!/usr/bin/env bash`; a header comment naming the requirement IDs
(`LINT-01/LINT-02/LINT-03`) and the decisions under test; **`set -u` only, never `set -e`**
(`tests/lib.sh:4-6` states the reason: a failed assertion must record and continue); the
`# shellcheck source=./lib.sh` directive line immediately before the `source` line; the
`source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"` idiom (this is how the test locates the
library — not `$REPO_ROOT`, which does not exist yet at that point); paths to sibling
artefacts built from `"$(dirname "${BASH_SOURCE[0]}")/..."` or from `$REPO_ROOT` (set by
`lib.sh:8`).

**Path-to-script-under-test idiom:** never hardcode a path — call the `lib.sh` accessor.
`tests/lib.sh:13-19`:

```bash
# init_py — the absolute path to the script under test. Tests call
# `python3 "$(init_py)" ...` because the bash harness has no
# `${CLAUDE_SKILL_DIR}` expansion (that is a Claude Code harness-side
# substitution, not an environment variable — RESEARCH assumption A4).
init_py() {
  echo "$REPO_ROOT/skills/dossier-init/scripts/init.py"
}
```

`tests/test-lint.sh` must invoke `python3 "$(lint_py)" "$dossier"`, mirroring
`python3 "$(init_py)" --target "$d" ...` used at `test-init-empty.sh:14`,
`test-init-adopt.sh:21,44,56,72,80` and `test-init-fr.sh:18`.

**Exit-code capture idiom — the exact three lines** (`test-init-empty.sh:12-21`,
`test-init-adopt.sh:20-22`):

```bash
status=0
python3 "$(init_py)" \
  --target "$d" \
  --language en \
  >"$d.stdout1" 2>"$d.stderr1" || status=$?
assert_eq 0 "$status" 'init exits 0 on an empty repo'
```

and the capture-into-a-variable variant (`test-init-adopt.sh:80`):

```bash
outD=$(python3 "$(init_py)" --target "$dD" --propose-renames 2>"$dD.err") || statusD2=$?
```

Both matter: the first is the shape for the exit-1/exit-2 lint cases, the second is the shape
for `assert_lint`'s `LINT_OUT` capture.

**Fixture-consumption + cleanup pattern** (`test-init-adopt.sh:17-18, 33`):

```bash
fx="$(bash "$FIXTURE_SCRIPT")"
cp -R "$fx" "$fx.snap"
...
rm -rf "$fx" "$fx.snap" "$fx.out" "$fx.err"
```

The generator is run with `bash "$SCRIPT"` and its stdout *is* the path; the caller owns
cleanup (the generator installs no `trap`). Per P-12, `test-lint.sh` should additionally
install `trap 'rm -rf "$FIXTURES"' EXIT` so nine trees do not leak when an assertion fails
mid-file.

**Byte-exact output comparison pattern** (`test-init-adopt.sh:23-24`) — for D-04's
"two consecutive runs are byte-identical" assertion, reuse the `diff`-into-`assert_eq ''`
idiom rather than a golden file (D-30 adds no golden):

```bash
assert_eq '' "$(diff "$fx.out" "$GOLDEN" 2>&1)" 'Case A: the proposal matches the golden byte for byte'
assert_eq '' "$(diff -r "$fx.snap" "$fx" 2>&1)" 'Case A: --propose-renames wrote nothing to the fixture'
```

The second line is also the ready-made assertion for "the linter never writes": snapshot the
fixture with `cp -R`, lint it, `diff -r`.

**Inline assertion pattern when no helper fits** (`test-init-adopt.sh:26-31`) — do not invent a
new helper for a one-off; write the if/else against the shared counters:

```bash
if [ -e "$fx/dossier.yaml" ]; then
  echo "FAIL: expected --propose-renames NOT to write dossier.yaml" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
else
  TESTS_PASSED=$((TESTS_PASSED + 1))
fi
```

Note the shape precisely: failure message to **stderr**, prefix `FAIL: `, then the counter
increment; success is a bare increment.

**Case-sectioning comment pattern** (`test-init-adopt.sh:16, 35, 50, 69`) — one `# --- Case X:
<what> ---` banner per scenario, variables suffixed per case (`dB`, `statusB`). With eleven
finding classes, `test-lint.sh` should use the same banners (`# --- E4: filename does not match
YYYY-MM-DD_slug ---`).

**Closing line:** every test file ends with a bare `finish` (`test-init-empty.sh:311`,
`test-init-adopt.sh:87`, `test-init-fr.sh`, `test-skill-shape.sh:79`).

**Executable convention:** commit mode `100755` (all five existing `tests/*.sh` are `100755`).
`assert_exec` exists at `tests/lib.sh:51-59` and is currently used by **no** test file —
`tests/test-lint.sh` asserting `assert_exec "$(lint_py)"` (RESEARCH LINT-03 row) is its first
consumer; the helper needs no change.

**Bash dialect (P-10, bash 3.2 via `run.sh:15`'s plain `bash "$f"`):** the five existing files
use only `[ ... ]`, `$((...))`, `case`, `local`, `$(...)`. No `declare -A`, no `mapfile`, no
`${var,,}`, no `**`. Copy that restraint.

---

### `tests/fixtures/make-lint-fixtures.sh` (test fixture generator, file-I/O)

**Analog:** `tests/fixtures/make-adopt-fixture.sh` — the whole file is the pattern (77 lines).

**Header + contract** (`make-adopt-fixture.sh:1-16`):

```bash
#!/usr/bin/env bash
# tests/fixtures/make-adopt-fixture.sh — builds a throwaway, origin-shaped
# repository for SCAF-06's adoption-detection tests (D-13, D-14, D-17).
#
# CONFIDENTIALITY (D-13, T-01-26): only folder and file *names* are used, ...
#
# Takes no arguments. Creates its own throwaway tree under `mktemp -d` and
# never writes anywhere else. Echoes the tree's path on success.
set -eu

d="$(mktemp -d)"
```

Three contract points to copy verbatim: **`set -eu`** (generators abort on first failure —
unlike test files, which use `set -u` only); the argument/side-effect contract stated in the
header comment (`make-lint-fixtures.sh` takes the clean tree path as `$1`, D-29, so say so
there); and `d="$(mktemp -d)"` as the single writable root.

**Local writer-helper pattern** (`make-adopt-fixture.sh:18-22`):

```bash
write_placeholder() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  printf 'placeholder\n' >"$path"
}
```

The generator defines its own small helpers (it does **not** source `lib.sh`). Use the same
shape for the violation injectors (e.g. `inject_e2() { local root="$1"; ... }`), and use
`printf ... > file` or a `python3 - <<'PY'` block — **never `sed -i`** (P-11: BSD needs
`sed -i ''`, GNU refuses the argument).

**Sectioning comments** (`make-adopt-fixture.sh:24, 29, 39, 45, 51, 58`):

```bash
# --- client/ — the seven living files + README (D-14's rename source) ---
```

One banner per fixture, naming the decision ID it exists for — here, one per error class
(`# --- E8: a .claude/ folder below the root (uncommittable, .gitignore:2) ---`).

**Git-init pattern when the fixture must be a repo** (`make-adopt-fixture.sh:67-71`):

```bash
git -C "$d" init -q
git -C "$d" config user.email "test@example.invalid"
git -C "$d" config user.name "Test Runner"
git -C "$d" add -A
git -C "$d" commit -q -m "fixture: origin-shaped tree"
```

`lint.py` never calls git, so the lint fixtures need this only if a test also exercises
`init.py` (which requires a repo — see `scratch_repo()` at `tests/lib.sh:22-29`, which already
does the same three git lines and is the right helper for the clean fixture per D-31).

**Exit contract** (`make-adopt-fixture.sh:77`): the last statement is `echo "$d"`, with **no
`trap`** — the caller cleans up. Preserve exactly this contract (P-12).

---

### `tests/fixtures/lint/fr/` (test data, static French tree)

**Analog (content shape):** `skills/dossier-init/templates/fr/HISTORY.md` — what a French
living file legitimately looks like, and the proof that the protocol keyword stays English:

```markdown
# Historique

Last updated: YYYY-MM-DD

<!-- Mis à jour quand : après chaque appel, mail ou document envoyé. -->

## Chronologie

<!-- - Exemple : Jane Doe (Acme) demande le livrable pour le 2026-10-01 (appel @12:34). -->
```

Three things to carry into the fixture: `Last updated:` in English on line 3 (the E7 probe for
ROADMAP criterion 3); headings and prose in French; the example bullet shipped as a
**whole-line HTML comment**, which is why a clean scaffold raises zero W2 (P-03 — and why the
fixture must add a genuine multi-line `<!--` / `-->` block, since the shipped templates contain
none). In the fixture the literal `YYYY-MM-DD` becomes a real date (`init.py:281-288`
`render_template()` substitutes it at scaffold time).

**Analog (how French content is asserted):** `tests/test-init-fr.sh:26-40`:

```bash
assert_grep_e '^templates: fr' "$d.stdout"
assert_grep '^language: fr$' "$d/dossier.yaml"
assert_grep_e '^## Chronologie$' "$d/dossier/HISTORY.md"
assert_grep_e "^## Côté donneur d'ordre\$" "$d/dossier/ACTORS.md"
```

Note the quoting idiom for French content containing an apostrophe: switch the outer quotes to
`"` and escape the trailing `$` (`"^## Côté donneur d'ordre\$"`), or use `'\''`
(`test-init-fr.sh:21`: `--counterpart 'Acme Consulting|donneur d'\''ordre|Jane Doe'`). Both are
already in the file; do not invent a third.

**Content the fixture must carry** (from RESEARCH Example 5 and P-04): the `fichier` /
`hiérarchie` bait line, so a linter missing word boundaries fails loudly; `demain`,
`la semaine prochaine`, `récemment` for W1 across both `dossier/` and `knowledge/`; a
`Probablement` / `reconstruit` line for the opinion-marker suppression of W2; ASCII `'` in
`aujourd'hui` (the shipped French templates contain zero U+2019).

---

### `tests/lib.sh` (MODIFIED — additive only, D-27)

**Analog:** the file itself. Two shapes to clone, nothing to change.

**Accessor shape to clone** (`tests/lib.sh:13-19`, quoted in full above): `lint_py()` is
`init_py()` with the path swapped to `"$REPO_ROOT/scripts/lint.py"`, keeping the explanatory
comment style. Place it immediately after `init_py()` so the two read as a pair.

**Assertion shape to clone** (`tests/lib.sh:94-102`) — the canonical helper body, `local`
declarations on one line, failure to stderr with a label, counter increments:

```bash
assert_eq() {
  local expected="$1" actual="$2" label="$3"
  if [ "$expected" = "$actual" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "FAIL: $label (expected '$expected', got '$actual')" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}
```

**The exact existing surface no new helper may disturb** (D-27):

| Name | Line | Signature / behaviour |
|------|------|-----------------------|
| `REPO_ROOT` | 8 | `"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"` |
| `TESTS_PASSED` / `TESTS_FAILED` | 10-11 | integers, both start at `0` |
| `init_py()` | 17-19 | no args; echoes the absolute path |
| `scratch_repo()` | 22-29 | no args; `mktemp -d` + `git init -q` + `user.email`/`user.name`; echoes the path |
| `assert_file PATH` | 31-39 | `[ -f ]` |
| `assert_dir PATH` | 41-49 | `[ -d ]` |
| `assert_exec PATH` | 51-59 | `[ -x ]` — currently unused by any test |
| `assert_grep REGEX PATH` | 63-71 | `grep -q -- "$regex" "$path"` (basic regex) |
| `assert_grep_e REGEX PATH` | 74-82 | `grep -Eq -- "$regex" "$path"` (extended regex) |
| `assert_not_grep REGEX PATH` | 84-92 | negation of `assert_grep` |
| `assert_eq EXPECTED ACTUAL LABEL` | 94-102 | string compare; label printed on failure |
| `finish()` | 105-111 | prints `PASS $TESTS_PASSED FAIL $TESTS_FAILED`; exits 1 if any failed, else 0 |

Argument order is **not uniform** and must be respected: the `grep` family takes
`(REGEX, PATH)`, `assert_eq` takes `(EXPECTED, ACTUAL, LABEL)`. New lint helpers should follow
`assert_eq`'s "label last" convention.

**Recommended additive shape** (RESEARCH Pattern 5; `case`/glob keeps it bash-3.2-safe and
subprocess-free): `lint_py()`, `assert_lint DOSSIER EXPECTED_EXIT LABEL` (sets `LINT_OUT` /
`LINT_ERR`, then delegates to `assert_eq`), `assert_finding ID LABEL`,
`assert_no_finding ID LABEL`. Note `set -u` is active, so any new global (`LINT_OUT`,
`LINT_ERR`) must be initialised at the top of `lib.sh` beside `TESTS_PASSED`/`TESTS_FAILED`,
or every read before the first `assert_lint` aborts the test file.

---

### `skills/dossier-init/scripts/init.py` (MODIFIED — producer hardening, D-24.3)

**Analog:** the file itself, `init.py:193-223`. The exact current bytes to edit:

```python
# init.py:211
_SAFE_PLAIN_SCALAR_RE = re.compile(r"^[A-Za-z][A-Za-z0-9_-]*$")


# init.py:214-223
def emit_scalar(key, value):
    """Return `key: value`, safe for any user-supplied string in `value`.

    Emits an unquoted YAML plain scalar when `value` matches
    _SAFE_PLAIN_SCALAR_RE (preserving today's nominal output byte for byte),
    otherwise routes through yaml_quote() -- the same escaping every other
    free-text field in this file already goes through.
    """
    text = value if _SAFE_PLAIN_SCALAR_RE.match(value) else yaml_quote(value)
    return "{}: {}".format(key, text)
```

The change is one constant plus one expression (`re.fullmatch` for debt (b), a reserved-word
frozenset for debt (a)); RESEARCH Example 6 gives the target code. Two constraints from the
surrounding file:

- The 18-line rationale comment at `init.py:193-210` is the precedent for how a security-shaped
  change is documented here — a new comment block explaining the Norway problem and pointing at
  `lint.py`'s schema as the single typing authority belongs above the new constant, in the same
  voice (ASCII `--`, cites `T-01-01` / `D-24` style identifiers).
- `emit_scalar()` has exactly **two** call sites, both inside `render_dossier_yaml()`:
  `init.py:254` (`emit_scalar("language", cfg["language"])`, inside the `lines = [...]` literal)
  and `init.py:275` (`lines.append(emit_scalar("status_header", cfg["status_header"]))`).
  Nothing else calls it; `render_dossier_yaml`'s docstring (`init.py:247-252`) explicitly says
  "Emission only -- this script never parses YAML. Parsing an existing dossier.yaml is Phase 2's
  problem" — keep that sentence true.

**Do not touch `skills/dossier-init/SKILL.md`** (P-09). `tests/test-skill-shape.sh:73-74`:

```bash
OUT_OF_SCOPE_COUNT=$(grep -ci -E 'stop hook|lint\.py|hooks\.json|marketplace\.json|commands/' "$SKILL_MD")
assert_eq 0 "$OUT_OF_SCOPE_COUNT" 'no mention of the Phase 2 linter, hooks.json, marketplace.json or a commands/ folder'
```

Any mention of `lint.py` in that file turns this assertion red.

---

### `tests/test-init-empty.sh` (MODIFIED — two new assertions, D-24.4)

**Analog:** the two blocks already in the file that assert on `--language` serialisation,
`test-init-empty.sh:262-283`. The new cases (`--language no` → `^language: "no"$`, and the
no-blank-line case for debt (b)) go immediately after them, in the same shape — a fresh
`scratch_repo`, a numbered variable suffix continuing the existing `d10`/`d11`/`d12`/`d13`
sequence, a comment explaining *why the assertion is red without the fix*:

```bash
# Regression (correctif 1, tour 2 -- the CAUSE): `language` and
# `status_header` are CLI-fed free text that bypassed yaml_quote() entirely
# (T-01-01). `language` had no argparse `choices=` (it cannot: language
# codes are open-ended), so emit_scalar()'s allowlist is the only guard --
# assert it actually quotes a colon and strips an embedded newline instead
# of injecting a key.
d10=$(scratch_repo)
status11=0
python3 "$(init_py)" \
  --target "$d10" \
  --language 'en: draft' \
  >"$d10.stdout" 2>"$d10.stderr" || status11=$?
assert_eq 0 "$status11" 'init exits 0 with a colon in --language'
assert_grep '^language: "en: draft"$' "$d10/dossier.yaml"
rm -rf "$d10" "$d10.stdout" "$d10.stderr"

d11=$(scratch_repo)
status12=0
python3 "$(init_py)" \
  --target "$d11" \
  --language "$(printf 'en\ninjected: pwned')" \
  >"$d11.stdout" 2>"$d11.stderr" || status12=$?
assert_eq 0 "$status12" 'init exits 0 with a newline in --language'
assert_grep '^language: "eninjected: pwned"$' "$d11/dossier.yaml"
assert_not_grep '^injected:' "$d11/dossier.yaml"
rm -rf "$d11" "$d11.stdout" "$d11.stderr"
```

Per-case teardown (`rm -rf "$dN" "$dN.stdout" "$dN.stderr"`) is mandatory here — every case in
this file cleans up immediately after its assertions. `printf` inside `$(...)` is the
established way to build a payload containing a newline. For literal-backslash expectations the
file drops to `grep -qF --` inside an inline if/else (`test-init-empty.sh:230-238`) with a
comment explaining why BRE is unreliable — reuse that if a new assertion needs it.

The existing assertions that must stay green: `^language: en$` and `^staleness_days: 7$`
(`test-init-empty.sh:35-36`), `^language: "en: draft"$`, `^language: "eninjected: pwned"$`,
plus `^language: fr$` (`test-init-fr.sh:28`). None involves a YAML reserved word, so the D-24.3
edit regresses none of them (RESEARCH "Runtime State Inventory").

## Shared Patterns

### ASCII-only source text

**Source:** `skills/dossier-init/scripts/init.py` (whole file), `tests/*.sh` (whole files)
**Apply to:** `scripts/lint.py`, `tests/test-lint.sh`, `tests/fixtures/make-lint-fixtures.sh`
Comments and docstrings write `--` not an em dash, `Sec3.2` not `§3.2`, straight quotes only.
Non-ASCII appears **only** inside French dossier *content* (`templates/fr/*.md`,
`tests/fixtures/lint/fr/`) and in the French assertion strings of `tests/test-init-fr.sh`.

### Comment doctrine: why, with an identifier

**Source:** `init.py:42-47`, `init.py:193-210`, `make-adopt-fixture.sh:45-46`,
`test-init-empty.sh:206-217`
**Apply to:** every new file
Each non-obvious block carries a comment that (a) names the decision/requirement identifier
(`D-29`, `LINT-01`, `spec Sec3.2`, `P-04`) and (b) explains the failure mode it prevents, not
what the code does. In test files the doctrine is stronger still: the comment says why the
assertion is *red without the fix*.

### Shared pass/fail counters, never `set -e` in a test file

**Source:** `tests/lib.sh:4-11` and `finish()` at `:105-111`
**Apply to:** `tests/test-lint.sh`, `tests/lib.sh` additions
`set -u` only; a failed assertion increments `TESTS_FAILED`, prints `FAIL: ...` to stderr and
execution continues; the file ends with `finish`. Generators (`make-*.sh`) are the exception:
they use `set -eu`.

### Dispatcher contract — never edit `tests/run.sh`

**Source:** `tests/run.sh:1-3, 11, 15`
**Apply to:** `tests/test-lint.sh`

```bash
# tests/run.sh — dispatcher. Runs every tests/test-*.sh file with bash and
# reports a summary. Adding a test file never requires editing this script.
...
for f in "$DIR"/test-*.sh; do
  ...
  if bash "$f" >/tmp/gsd-test-output.$$ 2>&1; then
```

Dropping `tests/test-lint.sh` in is sufficient; `run.sh` must go from `TOTAL: 5 files, 0 failed`
to `TOTAL: 6 files, 0 failed` with zero diff to itself. Note `bash "$f"` — plain `bash` (3.2 on
macOS), and stdout+stderr are both captured, so a test file's stderr is only shown on failure.

### Stdlib-only, no subprocess, no network

**Source:** `CLAUDE.md` ("`lint.py` is Python 3 standard library only"), `init.py:9-13`
("never prompts, never reads a TTY, and never shells out")
**Apply to:** `scripts/lint.py`
`init.py` does import `subprocess` (for `git` in `propose_renames`); `lint.py` must **not** —
it runs no subprocess at all (RESEARCH Security Domain). Its import list is `argparse`,
`datetime`, `json`, `os`, `re`, `sys`, `unicodedata`, `from pathlib import Path`.

### Executable + committed mode 100755

**Source:** `git ls-files -s` → `100755` for `init.py`, `run.sh`, `lib.sh`, every `test-*.sh`,
`make-adopt-fixture.sh`
**Apply to:** `scripts/lint.py`, `tests/test-lint.sh`, `tests/fixtures/make-lint-fixtures.sh`
Shebang + `chmod +x` before the commit; `assert_exec "$(lint_py)"` pins it.

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| the YAML-subset parser inside `scripts/lint.py` (`Scalar`, `parse_yaml_subset`, `apply_schema`) | parser / schema | transform | Nothing in this repository parses YAML — `render_dossier_yaml()`'s own docstring (`init.py:247-252`) says so explicitly. Use RESEARCH Examples 1-3 (executed prototypes) as the pattern source instead of a codebase analog. The only in-repo constraint is the *output bytes* of `render_dossier_yaml()` (`init.py:247-279`), which the parser must read back. |
| `tests/fixtures/lint/clean/` (if committed at all) | test data | static | No committed fixture *tree* exists — `make-adopt-fixture.sh` generates its tree at runtime, and `tests/golden/adopt-proposal.txt` is a single text file. D-31 + RESEARCH Pattern 6 / Q-7 recommend generating it from `init.py` via `scratch_repo()` rather than committing; if the planner keeps a committed copy, there is no precedent to follow and the drift assertion of Q-7 must be written from scratch. |

## Metadata

**Analog search scope:** `scripts/` (does not exist yet), `skills/dossier-init/scripts/`,
`skills/dossier-init/templates/{en,fr}/`, `tests/`, `tests/fixtures/`, `tests/golden/`,
repository root (`CLAUDE.md`, `.gitignore`)
**Files scanned:** 14 source files read (1 Python, 7 bash, 1 template, `.gitignore`, `CLAUDE.md`,
plus CONTEXT.md and RESEARCH.md); `git ls-files` used to confirm every analog is tracked
**Pattern extraction date:** 2026-09-17
