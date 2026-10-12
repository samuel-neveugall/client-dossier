# Phase 2: Linter & Test Harness - Research

**Researched:** 2026-09-17
**Domain:** Python 3 standard-library static analysis of a fixed-layout Markdown/YAML tree, plus a bash-only test harness
**Confidence:** HIGH (the entire domain is in-repo; every load-bearing claim below was reproduced by running the real `init.py`, the real `tests/run.sh`, and a throwaway prototype linter against the real scaffold output)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

Copied verbatim from `.planning/phases/02-linter-test-harness/02-CONTEXT.md` `<decisions>`.

**Invocation, root discovery, output**

- **D-01:** CLI is `python3 scripts/lint.py [PATH]`, `PATH` optional and defaulting to `.`.
  From `PATH` the linter walks **upward** to the nearest `dossier.yaml` (spec §3.2: "the
  plugin locates a dossier by finding `dossier.yaml` in the working directory or a parent");
  that file's directory is the dossier root and every check is relative to it. No other flag
  in v1 — no `--format`, no `--fix`, no `--quiet`.
- **D-02:** No `dossier.yaml` found upward → **exit 2** with
  `error: no dossier.yaml found from <path> upward` on stderr and no findings. Exit 1 stays
  reserved for "this dossier has errors", which is the only meaning `dossier-status` and the
  `dossier-lint` command can rely on later. — Assumption A-01.
- **D-03:** A repository may hold several dossiers (spec §3.2). The linter lints **the nearest
  one only**: any subdirectory that itself contains a `dossier.yaml` is a boundary and is
  skipped whole. Never recurse into a sub-dossier, never merge two configs.
- **D-04:** One finding per line on stdout, in the compiler shape
  `<relative/path>:<line>: ERROR [E4] <message>` (line `0` when the finding is about a file or
  a folder as a whole, e.g. a filename). Findings are sorted by path then line so output is
  byte-stable. Last line: `N error(s), M warning(s)`. Errors and warnings are distinguished by
  the `ERROR`/`WARNING` token, never by exit code alone.
- **D-05:** Every check has a **stable identifier** (`E1`…`E9`, `W1`, `W2`) printed inside the
  message. Tests assert on the identifier, not on the English prose, so message wording can be
  improved later without breaking the harness. — **Reversibility:** costly.
- **D-06:** `.gitkeep` files are ignored everywhere (LINT-01, spec §3.2). `README.md` at the
  root of `sources/`, `dossier/` and `outbound/` is ignored by the outbound checks — **this is
  load-bearing**: the Phase 1 template `templates/en/README-outbound.md` quotes the status
  header verbatim, including the literal `Deadline: YYYY-MM-DD` and `sent <date time> by
  <name>`. Without this exemption every freshly scaffolded dossier fails its own linter.

**The nine error classes and their mapping**

| ID | Error class | Spec §4.4 | Requirement |
|----|-------------|-----------|-------------|
| E1 | outbound file with no status header | check 1 | LINT-01 |
| E2 | `sent` (or `reviewed by`) status without a date or without a sender | check 1 | LINT-01 |
| E3 | `Deadline:` that is not an absolute date | check 1 | LINT-01 |
| E4 | outbound filename not matching `YYYY-MM-DD_slug` | check 2 | LINT-01 |
| E5 | a confidential name found under `outbound/` | check 3 | LINT-01 |
| E6 | `consent_recorded: true` with an empty/absent `consent_source` | check 3 | LINT-01 |
| E7 | living file without a valid `Last updated:` line | check 4 | LINT-01 |
| E8 | a `.claude/` folder below the repository root | check 7 | LINT-01 |
| E9 | rendered deliverable without its source file beside it | check 8 | LINT-01 |
| W1 | relative-date word in `dossier/` or `knowledge/` | check 5 | LINT-01 |
| W2 | bullet line in a living file with no parenthetical source | check 6 | LINT-01 |

- **D-07 (E1):** "Outbound file" = every file under `outbound/` except `.gitkeep`, `README.md`,
  and rendered binaries (`.pdf`, `.docx`, images). Status block within the **first 10 lines**;
  English protocol keywords grepped, comment syntax around them ignored (`<!-- -->`, `#`).
  "Complete" = `Status:`, `To:` and `Written by:` present, plus `Subject:` for files under
  `outbound/mails/`. `Deadline:` and `Rules:` stay optional. — Assumption A-02.
- **D-08 (E2):** `Status:` must be `draft`, `reviewed by <non-empty name>`, or
  `sent <YYYY-MM-DD>[ <time>] by <non-empty name>`. An absent date, a relative date, or an
  absent/empty sender is E2. `reviewed by` with no name is E2 as well.
- **D-09 (E3):** `Deadline:` value must match `^\d{4}-\d{2}-\d{2}$` **and** be a real calendar
  date (validated with `datetime.date`).
- **D-10 (E4):** Files directly under `outbound/deliverables|mails|calls/` must match
  `^\d{4}-\d{2}-\d{2}_[a-z0-9]+(-[a-z0-9]+)*\.[A-Za-z0-9]+$`, date validated as in D-09.
  `.gitkeep` and `README.md` exempt. — Assumption A-03.
- **D-11 (E5):** Each entry of `confidential_names` searched case-insensitively, with word
  boundaries (`(?<!\w)…(?!\w)`), in the **text content and in the filename** of every file
  under `outbound/`. Text normalised with `unicodedata.normalize("NFC", …)`. The whole check is
  suppressed when `consent_recorded: true` **and** `consent_source` is non-empty.
- **D-12 (E6):** `consent_recorded: true` with an empty or missing `consent_source` is
  reported at `dossier.yaml:<line>`.
- **D-13 (E7):** "Living file" = exactly the seven files under `dossier/`. The line must carry
  an absolute, real date. A living file that is **absent** is reported under E7 with its own
  message. — Assumption A-04.
- **D-14 (E8):** Any directory named `.claude` whose path is not exactly `<root>/.claude`.
- **D-15 (E9):** Under `outbound/deliverables/`, a `.pdf` or `.docx` must have a sibling with
  the same stem and a `.html` or `.md` extension. The reverse is fine and silent.

**The warning boundary**

- **D-16:** A rule a regex can decide with certainty on protocol keywords and paths is an
  **error**; a rule that has to guess at natural language is a **warning**.
- **D-17 (W1):** Relative-date words looked for in `dossier/` and `knowledge/` only,
  case-insensitively, on NFC-normalised text, with word boundaries.
- **D-18 (W2):** A bullet line (`- ` / `* ` at the start of a stripped line) in one of the
  seven living files must end with a parenthetical source, i.e. match `\([^()]+\)\.?\s*$`.
  Exempt: lines inside an HTML comment, headings, and lines carrying an allowed **opinion
  marker**.

**Language word lists**

- **D-19:** The two word lists live in `lint.py` as a single module-level constant
  `LANGUAGE_WORDS = {"en": {...}, "fr": {...}}`, physically separated from the protocol-keyword
  constants. No per-language table of labels exists or may be added.
- **D-20:** v1 ships `en` and `fr`. Selection driven by `language:` from `dossier.yaml`; an
  unknown language means W1/W2's marker list is skipped with a single informational line.
- **D-21:** v1 word lists:
  - relative dates `en`: tomorrow, yesterday, today, next week, last week, this week, next
    month, last month, soon, recently, in a few days
  - relative dates `fr`: demain, hier, aujourd'hui, la semaine prochaine, la semaine dernière,
    cette semaine, le mois prochain, le mois dernier, bientôt, récemment, prochainement,
    dans quelques jours
  - opinion markers `en`: reconstructed, I think, probably, it seems, apparently, maybe
  - opinion markers `fr`: reconstruit, je pense, probablement, il semble, apparemment,
    peut-être
  — Assumption A-06.

**`dossier.yaml`: the YAML-subset parser and the JSON fallback**

- **D-22:** The parser reads only `language`, `confidential_names`, `consent_recorded`,
  `consent_source`, `status_header`, `staleness_days`, `date_format` and ignores every other
  key. Supported subset: `key: value`, inline lists `[ a, b ]`, block lists `- item`, `#`
  comments, single and double quotes. Unknown or unparseable **lines** are skipped with a
  warning, not a crash; an unreadable file is exit 2 as in D-02.
- **D-23:** Typing fidelity — every string-valued key is read **as a string, whatever its
  spelling**: `language: no` is the string `"no"`, never boolean `False`. Only
  `consent_recorded` is read as a boolean and only `staleness_days` as an integer.
- **D-24 (SETTLED 2026-09-17 by the mission manager).** Retained: **option D — per-field typing
  in `lint.py` (a schema) plus a minimal typographic hardening of the producer.** The rule,
  verbatim:

  1. **Parser (`lint.py`)** — always returns **raw strings** (plus lists/dicts for structure):
     unquoting of `"…"`/`'…'`, flow sequences `[ a, b ]`, block sequences of mappings
     (`counterparts`), stripping of `#` comments **quote-aware**. **No** implicit
     int/bool/null/float/date conversion at the scalar level.
  2. **Per-field schema, above the parser**:
     - `version` → int (`re.fullmatch(r"[-+]?[0-9]+")`), must equal `1`, otherwise the error
       "dossier.yaml unreadable".
     - `language`, `consent_source`, `timestamps`, `date_format`, `status_header`,
       `counterparts[].name|role`, `counterparts[].contacts[]`, `confidential_names[]` →
       **str verbatim**, whatever the spelling (`no` stays `"no"`).
     - `staleness_days` → int via `re.fullmatch(r"[-+]?[0-9]+")` on the raw scalar; absent →
       default 7; present and not an integer, or ≤ 0 → an error naming the field.
     - `consent_recorded` → bool, **only** an unquoted YAML 1.2 Core Schema scalar:
       `true|True|TRUE` → true, `false|False|FALSE` → false; absent → false;
       `yes|no|on|off|y|n|1|0` or any quoted form (`"true"`) → **error**
       "consent_recorded must be an unquoted boolean: true or false". **Never** a silent
       coercion to true.
  3. **Producer (`init.py`)** — a serialisation rule, not typing: `_SAFE_PLAIN_SCALAR_RE`
     moves to `re.fullmatch` (debt (b)), and a scalar whose casefold belongs to
     `{y, n, yes, no, on, off, true, false, null, ~}` is routed to `yaml_quote()` (debt (a)).
     Expected output: `--language no` → `language: "no"`; `en`, `fr`, `es`, `required` stay
     unquoted, byte-for-byte identical to today. `consent_recorded` is still emitted unquoted
     `true`/`false`, `staleness_days` as a bare integer.
  4. **New tests the plan must provide**: `^language: "no"$` after `--language no`; no blank
     line after a value ending in `\n`; a round-trip `init.py` → `lint.py`'s parser asserting
     `language == "no"`; error fixtures `consent_recorded: yes` and `consent_recorded: "true"`
     (exit 1, message naming the field); fixture `consent_recorded: true` +
     `consent_source: ""` (exit 1).

  **Measured regression cost on Phase 1**: `emit_scalar()` has only 2 call sites, and no
  assertion in `tests/test-init-empty.sh`, `tests/test-init-fr.sh` nor the golden
  `tests/golden/adopt-proposal.txt` bears on a reserved word. The plan must nevertheless carry
  an explicit task "the Phase 1 suite stays green" (`bash tests/run.sh`).
- **D-25:** JSON fallback = **the same fixed filename**. If `dossier.yaml`'s content starts
  with `{` it is parsed with the `json` module. No `dossier.json` name is introduced. — A-05.

**Test harness**

- **D-26:** One new file, `tests/test-lint.sh`. `tests/run.sh` is **not** modified.
- **D-27:** `tests/lib.sh` extended **additively only** — a `lint_py()` helper beside
  `init_py()`, and lint-specific assertion helpers built on the existing
  `TESTS_PASSED`/`TESTS_FAILED`/`finish()` machinery. The five Phase 1 test files must keep
  passing untouched.
- **D-28:** Fixtures under `tests/fixtures/lint/`. Two **committed static trees**:
  `tests/fixtures/lint/clean/` (exit 0, zero findings) and `tests/fixtures/lint/fr/` (French
  content, `language: fr`, relative-date words and unsourced bullets → exit 0 with W1/W2, and
  the English `Last updated:` label still found).
- **D-29:** The **error fixtures are generated at runtime** by
  `tests/fixtures/make-lint-fixtures.sh`, one throwaway tree per error class (E1…E9), each a
  copy of the clean base with exactly one violation injected, built under `mktemp -d`.
  `make-adopt-fixture.sh` is left untouched. — **Reversibility:** costly.
- **D-30:** Assertions on **exit code + finding identifier** (D-05), not on golden output
  files. No golden file is added for lint.
- **D-31:** The clean fixture is the regression guard for D-06. The planner should build it
  **by running `init.py`** into the fixture path (or by copying its exact output).

### Claude's Discretion

- Internal structure of `lint.py` (function decomposition, order of checks, single-pass vs
  per-check walk), exact wording of each message after its `[ID]` token, the internal shape of
  the fixture generator script, and how the clean fixture is materialised from `init.py`.

### Assumptions (to be validated by Samuel)

- **A-01 (D-02):** exit 2 when no `dossier.yaml` is found.
- **A-02 (D-07):** "complete" status header = `Status:` + `To:` + `Written by:` (+ `Subject:`
  under `outbound/mails/`). `Rules:` unchecked in v1.
- **A-03 (D-10):** slug charset `[a-z0-9]+(-[a-z0-9]+)*`.
- **A-04 (D-13):** an absent living file is reported under E7.
- **A-05 (D-25):** JSON fallback reuses the `dossier.yaml` filename.
- **A-06 (D-21):** the exact v1 word lists.

### Deferred Ideas (OUT OF SCOPE)

- `dossier-lint` slash command and `lint.py`'s invocation from `dossier-status` — Phase 6/7.
- The bare-skills fallback prose — belongs to the skills that call the linter, Phases 3/5/6.
- A `--fix` or `--format json` mode.
- Extending `LANGUAGE_WORDS` beyond `en`/`fr`.
- Git-awareness (linting only changed files).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| LINT-01 | `scripts/lint.py` (Python 3 stdlib only) implements all 8 mechanical checks from spec §4.4, exiting 1 on any error and 0 on warnings only, ignoring `.gitkeep` | §Architecture Patterns (walk strategy + per-check design), §Code Examples (validated prototype for all 9 error classes and 2 warnings), §Common Pitfalls P-01…P-06 (the false positives that would make a fresh scaffold fail its own linter), §Standard Stack (stdlib modules only) |
| LINT-02 | Fixture repositories: clean baseline, French-language fixture, error fixtures triggering every error class | §Architecture Patterns "Fixture materialisation", F-01…F-04 verified constraints (`.gitignore` blocks a committed `.claude/`; `sources/transcripts/` cannot be committed empty), §Code Examples (the nine injections, each proven to fire in isolation) |
| LINT-03 | A bash test runner asserts exit codes and messages, no framework beyond bash and python3 | §Architecture Patterns "Test-harness integration surface" (exact `lib.sh`/`run.sh` contract with line numbers), §Validation Architecture (criterion→command map + sampling rate), §Common Pitfalls P-10…P-13 (bash 3.2, BSD `sed -i`, `mktemp -d`) |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

Actionable directives extracted from `/Users/samuel/Documents/dev/client-dossier/CLAUDE.md`.
The planner must verify compliance; these carry the same authority as CONTEXT.md's locked
decisions, except where the spec overrides (CLAUDE.md's own precedence rule: the spec wins).

| # | Directive | Impact on this phase |
|---|-----------|----------------------|
| C-1 | "the plugin (skills, agents, scripts, docs, commit messages) is written in English" | `lint.py` code, comments, docstrings, messages, `tests/test-lint.sh` and commit messages are English. Only *dossier content* in a fixture is French. |
| C-2 | "Folder and file names are **fixed English names, never configurable**… Do not introduce a name mapping." | `FOLDERS`-equivalent constants in `lint.py` are literals; no config key may rename `outbound/` or `ACTORS.md`. |
| C-3 | "Protocol keywords are English too and never translated… The linter greps these keywords; do not add a per-language label table." | Re-states D-19. The **only** language-aware data is `LANGUAGE_WORDS`. |
| C-4 | "**Scripts carry mechanics.** Anything a regex can check belongs in `scripts/lint.py`, not in skill prose." | The linter is the mechanical authority; no judgement, no prose rules. |
| C-5 | "`lint.py` is Python 3 standard library only (tiny YAML-subset parser, JSON fallback); exit 1 on errors, 0 on warnings only." | No `pip install`, no vendored third-party file. |
| C-6 | "Mechanical tests in `tests/`: fixture repositories (including a French-content one…) and a bash runner asserting `lint.py` exit codes and messages. No test framework beyond bash and python3." | No pytest, no bats, no shunit2. |
| C-7 | "Sources are immutable" / "`consent_recorded: true` without a source is a lint error" | E6 is not optional; the linter itself never writes. |
| C-8 | "Local loading during development: `claude --plugin-dir .`" | Irrelevant to lint.py, but the plan must not move `.claude-plugin/plugin.json`. |
| C-9 | "No build, lint or test commands exist yet; add them here as they are created." | The plan **must** include a task updating `CLAUDE.md` with `python3 scripts/lint.py [PATH]` and `bash tests/run.sh`. This is a real, easily-forgotten deliverable. |

**Cross-cutting constraint discovered in the code, not in CLAUDE.md** — see P-09: an existing
Phase 1 test *forbids* mentioning `lint.py` in `skills/dossier-init/SKILL.md`.

## Summary

This phase has no external technology to research: it is 100% Python 3 standard library plus
POSIX bash, operating on a tree whose exact bytes are produced by code that already exists in
this repository. Research therefore took the form of **empirical validation**: I ran the real
`skills/dossier-init/scripts/init.py` to produce a clean English dossier and a clean French
dossier, wrote a ~285-line throwaway prototype implementing every decision in CONTEXT.md, and
ran it against both scaffolds, against nine injected error fixtures, against a French warning
fixture, against a nested sub-dossier, and against the three `dossier.yaml` typing cases D-24
names. The headline result is that **CONTEXT.md's design is implementable as written and a
freshly scaffolded dossier lints to `0 error(s), 0 warning(s)` in both languages** — ROADMAP
criterion 1 and criterion 3 are reachable, and each of E1…E9 fires exactly once in isolation
with no cross-contamination, which is exactly what D-29's isolation assertion needs.

Four findings change what the plan must contain. **(1)** D-24's `consent_recorded` rule is
*not implementable* by a parser that unquotes scalars before the schema runs: unquoting destroys
the very information the rule keys on, and `consent_recorded: "true"` becomes indistinguishable
from `consent_recorded: true` — my first prototype silently coerced it to `true`, the exact
failure D-24 forbids. The parser must return a **quotedness-preserving scalar record**
(`text`, `quoted`, `line`), not a bare `str`. **(2)** D-11's `(?<!\w)…(?!\w)` boundary
**cannot match a confidential name in a filename**, because `_` is a `\w` character and every
outbound filename is `YYYY-MM-DD_slug`: `2026-09-17_acme-proposal.md` is not flagged for the
name "Acme". Switching the boundary class to `[^\W_]` closes the gap while still rejecting
`Acmetal`, exactly as D-11 requires. **(3)** D-05 assigns identifiers to E1…E9/W1/W2 but D-24
mandates four *configuration* errors that have no identifier; they need one (recommended: `C1`)
or the tests cannot assert on them. **(4)** A committed clean fixture (D-28) silently loses
`sources/transcripts/`, because `init.py` writes no `.gitkeep` there and git does not track
empty directories — so the committed tree is *not* what `init.py` produces, which is the one
thing D-31 exists to guarantee.

Both Phase 1 debts reproduce exactly as the ROADMAP describes them, and D-24's measured
regression cost is **correct as written**: `emit_scalar()` has exactly two call sites, and no
Phase 1 assertion or golden bears on a YAML reserved word.

**Primary recommendation:** Build `lint.py` as a single stdlib file with a
quotedness-preserving scalar record feeding a per-field schema, one pruned `os.walk` pass
feeding per-check functions, and a `[^\W_]` boundary class for all name/word matching; build
the clean fixture by *running* `init.py` at test time rather than committing it, and reserve
`C1` for configuration errors before writing a single assertion.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Finding the dossier root (upward walk) | `scripts/lint.py` | — | D-01/D-02; each skill will re-implement its own discovery in Phase 3 (PROTO-08), but the linter owns its own so it stays callable standalone |
| Reading `dossier.yaml` (parse + type) | `scripts/lint.py` | — | C-5, D-22/D-24; the schema becomes the typing contract every later consumer reads the file through |
| Writing `dossier.yaml` (serialise) | `skills/dossier-init/scripts/init.py` | — | D-24 point 3; producer stays a pure serialisation rule, never a typing authority |
| Mechanical rule enforcement (E1…E9, W1, W2) | `scripts/lint.py` | — | C-4 — "anything a regex can check belongs in `scripts/lint.py`, not in skill prose" |
| Judgement / prose rules | `skills/*/SKILL.md` (Phase 3+) | — | Out of scope here; C-4's other half |
| Exit-code contract (0/1/2) | `scripts/lint.py` | consumers in Phases 5/6/7 | D-02; the only thing later phases may rely on |
| Fixture materialisation | `tests/fixtures/make-lint-fixtures.sh` + `init.py` | committed trees under `tests/fixtures/lint/` | D-28/D-29/D-31 |
| Assertion + reporting | `tests/test-lint.sh` on `tests/lib.sh` | `tests/run.sh` (untouched dispatcher) | D-26/D-27 |

## Standard Stack

This phase installs **nothing**. C-5 and C-6 forbid every external dependency.

### Core

| "Library" | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| Python 3 stdlib `re` | ships with 3.8+ | Every protocol-keyword, date, slug and word match | C-5 forbids alternatives `[VERIFIED: CLAUDE.md "Python 3 standard library only"]` |
| Python 3 stdlib `os` (`os.walk`) | 3.8+ | The single pruned tree walk | `dirnames` in-place pruning is the documented mechanism for D-03 `[VERIFIED: os.walk.__doc__ read from the local interpreter this session]` |
| Python 3 stdlib `pathlib` | 3.8+ | Path arithmetic, `relative_to`, suffix/stem | Keeps D-04's relative paths trivially correct |
| Python 3 stdlib `datetime` | 3.8+ | `datetime.date(y, m, d)` real-calendar validation | D-09 names it explicitly |
| Python 3 stdlib `unicodedata` | 3.8+ | `normalize("NFC", …)` before matching | D-11/D-17 name it explicitly; macOS NFD reproduced this session (P-05) |
| Python 3 stdlib `json` | 3.8+ | D-25's fallback when `dossier.yaml` starts with `{` | D-25 names it explicitly |
| Python 3 stdlib `argparse` | 3.8+ | `[PATH]` positional | Mirrors `init.py`'s established pattern `[VERIFIED: skills/dossier-init/scripts/init.py:689-723]` |
| Python 3 stdlib `sys` | 3.8+ | stderr for D-02, exit codes | — |
| bash | 3.2.57 on this machine | `tests/test-lint.sh`, `tests/fixtures/make-lint-fixtures.sh` | C-6; version measured this session (P-10) |

### Supporting

| Module | Purpose | When to Use |
|--------|---------|-------------|
| `os.path.commonpath` | Containment checks | Already the idiom in `init.py`'s `under_root()` `[VERIFIED: skills/dossier-init/scripts/init.py:294-298]` |
| `collections.namedtuple` or a `__slots__` class | The quotedness-preserving `Scalar` record (F-01) | Avoid `dataclasses` only if 3.6 support were needed — 3.7+ is fine; a `__slots__` class is smaller and has no import |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Hand-written YAML subset parser | PyYAML / ruamel.yaml | **Forbidden** by C-5 and spec §4.4 ("to avoid a dependency"). Also PyYAML defaults to YAML 1.1 and would reintroduce debt (a) on the consumer side `[CITED: github.com/yaml/pyyaml/issues/486]` |
| bash test file | pytest / bats / shunit2 | **Forbidden** by C-6 and spec §7 ("No test framework beyond bash and python3") |
| Committed error fixtures | runtime-generated (`mktemp -d`) | Settled by D-29 and **independently confirmed**: `.gitignore:2:.claude/` matches at any depth, so an E8 fixture is uncommittable (F-03) |
| A `Scalar` record | A parallel `raw_text` dict keyed by field name | Works, but two structures to keep in sync and no natural home for the line number D-04/D-12 need. The record carries text + quoted + line in one place |

**Installation:**

```bash
# none — nothing is installed in this phase
python3 --version   # must be >= 3.8 (measured on this machine: 3.14.6)
bash --version      # measured on this machine: 3.2.57(1)-release
```

## Package Legitimacy Audit

**Not applicable.** This phase installs no external package in any ecosystem. `scripts/lint.py`
is Python 3 standard library only (C-5, spec §4.4), and the test harness is bash + python3
only (C-6, spec §7). No `requirements.txt`, `pyproject.toml`, `package.json` or lockfile is
created or modified.

| Package | Registry | Verdict | Disposition |
|---------|----------|---------|-------------|
| *(none)* | — | — | — |

**Packages removed due to [SLOP] verdict:** none — none were proposed.
**Packages flagged as suspicious [SUS]:** none.

The planner must reject any task that introduces a dependency, including a vendored
single-file YAML parser: the spec's phrase is "a tiny YAML subset parser… to avoid a
dependency", and a vendored file is still a dependency for review and licensing purposes.

## Architecture Patterns

### System Architecture Diagram

```
                      argv[1] (optional PATH, default ".")
                                    │
                                    ▼
                        ┌───────────────────────┐
                        │  find_root()          │   walk UPWARD to the
                        │  D-01                 │   nearest dossier.yaml
                        └───────────┬───────────┘
                          not found │ found
                    exit 2 ◄────────┤
                     (D-02)         ▼
                        ┌───────────────────────┐
                        │  read dossier.yaml    │
                        │  first non-space char │
                        └───────┬───────┬───────┘
                          '{'   │       │ otherwise
                                ▼       ▼
                     ┌──────────────┐ ┌──────────────────────┐
                     │ json.loads   │ │ parse_yaml_subset()  │  D-22/D-24.1
                     │ + adapter    │ │ quote-aware # strip  │
                     │    D-25      │ │ flow/block sequences │
                     └──────┬───────┘ └──────────┬───────────┘
                            └────────┬───────────┘
                                     ▼
                        ┌──────────────────────────┐
                        │ Scalar(text, quoted,line)│   ← F-01: quotedness
                        └────────────┬─────────────┘      MUST survive
                                     ▼
                        ┌──────────────────────────┐
                        │ apply_schema()  D-24.2   │──► config errors (C1)
                        │ str / int / bool         │
                        └────────────┬─────────────┘
                                     ▼  Config(language, confidential_names,
                                     │         consent_recorded, consent_source, …)
                        ┌────────────┴─────────────┐
                        │  walk_tree()   D-03      │  one os.walk pass,
                        │  prune .git, sub-dossiers│  dirnames[:] pruning,
                        │  drop .gitkeep           │  followlinks=False
                        └────────────┬─────────────┘
                                     │ (files[], dirs[])
              ┌──────────┬───────────┼───────────┬──────────┬──────────┐
              ▼          ▼           ▼           ▼          ▼          ▼
         check_config  check_dirs  check_living  check_outbound   check_renders
          (E6)          (E8)        (E7)         (E1,E2,E3,       (E9)
                                                  E4,E5)
              │          │           │                │              │
              │          │           └── check_words (W1, dossier/ + knowledge/)
              │          │           └── check_bullets (W2, the 7 living files)
              └──────────┴───────────┴────────────────┴──────────────┘
                                     ▼
                        ┌──────────────────────────┐
                        │ findings.sort(path,line, │  D-04 byte-stable
                        │               ident)     │
                        │ print + "N error(s), M   │
                        │  warning(s)"             │
                        └────────────┬─────────────┘
                                     ▼
                          exit 1 if any ERROR else 0
```

Data flows one way. Nothing is written, no subprocess, no network — the linter is a pure
function of the filesystem plus `dossier.yaml`.

### Recommended Project Structure

```
scripts/
└── lint.py              # NEW — repo root scripts/, per Phase 1 D-05/D-06 (init.py stays
                         #       bundled in the skill; lint.py stays here)
tests/
├── run.sh               # UNCHANGED (D-26) — globs tests/test-*.sh
├── lib.sh               # EXTENDED ADDITIVELY (D-27) — lint_py() + lint assertions
├── test-lint.sh         # NEW (D-26)
├── test-init-*.sh (×4)  # UNCHANGED — must stay green
├── test-skill-shape.sh  # UNCHANGED — and see P-09, it constrains what you may write
├── golden/
│   └── adopt-proposal.txt   # UNCHANGED (D-30 adds no golden)
└── fixtures/
    ├── make-adopt-fixture.sh     # UNCHANGED (D-29)
    ├── make-lint-fixtures.sh     # NEW (D-29)
    └── lint/
        ├── clean/               # D-28 — see F-04 before committing it
        └── fr/                  # D-28
```

**Internal decomposition of `lint.py`** (Claude's discretion per CONTEXT.md; this is the
recommendation):

```
module docstring + "why" comments (init.py's convention)
── PROTOCOL KEYWORDS (fixed English, spec §3.2) ──────  # C-3: one clearly-labelled block
── LANGUAGE_WORDS (data, not protocol) ───────────────  # D-19: physically separated,
                                                       #       commented as distinct
── LAYOUT CONSTANTS (LIVING_FILES, OUTBOUND_SUBS, …) ─  # C-2: literals, never configurable
── Scalar / parse_yaml_subset / json_adapter ─────────  # D-22, D-24.1, D-25
── apply_schema ──────────────────────────────────────  # D-24.2
── find_root / walk_tree ─────────────────────────────  # D-01, D-03
── check_* (one function per ID, each yielding Findings)
── report / main
```

Order the checks by identifier (E1…E9, W1, W2) so the file reads in the same order as D-05's
table and as `tests/test-lint.sh`. One `os.walk` pass, results handed to per-check functions:
a per-check re-walk would be O(11×) for no benefit and would make the sub-dossier pruning
(D-03) a rule repeated eleven times instead of once.

### Pattern 1: Quotedness-preserving scalar (mandatory — F-01)

**What:** The parser returns a record, not a `str`.
**When to use:** Always, for every scalar in `dossier.yaml`, in both the YAML and JSON branches.
**Why:** D-24.2 says `consent_recorded` must be "**only** an unquoted YAML 1.2 Core Schema
scalar … or any quoted form (`"true"`) → **error**". D-24.1 simultaneously says the parser
performs "unquoting of `"…"`/`'…'`". Those two sentences are only compatible if the parser
records *that* it unquoted. A prototype that returned bare strings accepted
`consent_recorded: "true"` as `true` — the silent coercion D-24 explicitly forbids.
See §Code Examples, Example 2.

### Pattern 2: `[^\W_]` boundary class for every name and word match (mandatory — F-02)

**What:** Replace `(?<!\w)NAME(?!\w)` with `(?<![^\W_])NAME(?![^\W_])`.
**When to use:** E5 (confidential names, in both text and filename), W1 (relative dates), W2
(opinion markers).
**Why:** `\w` is `[a-zA-Z0-9_]` plus Unicode letters/digits
`[VERIFIED: re.__doc__, read from the local interpreter — "\w Matches any alphanumeric
character; equivalent to [a-zA-Z0-9_] in bytes patterns … (letters plus digits plus
underscore)"]`. Every outbound filename is `YYYY-MM-DD_slug.ext` (D-10), so a confidential name
at the head of the slug is *always* preceded by `_` and `(?<!\w)` always fails. Measured this
session:

| Haystack | Name | `(?<!\w)` | `[^\W_]` | Desired |
|----------|------|-----------|----------|---------|
| `2026-09-17_acme-proposal.md` | Acme | **False** | True | True (a leak) |
| `acme_report.md` | Acme | **False** | True | True (a leak) |
| `Acmetal is fine` | Acme | False | False | False (D-11's own example) |
| `AcmeCorp` | Acme | False | False | False |
| `We met Acme yesterday` | Acme | True | True | True |
| `Big Telco signed (mail …)` | Big Telco | True | True | True |

`[^\W_]` is a strict improvement: it satisfies D-11's stated requirement ("so 'Acme' does not
fire inside 'Acmetal'") *and* closes two real leak paths. This is an implementation detail
inside D-11's intent, not a reopening of D-11.

### Pattern 3: One pruned `os.walk` pass (D-03)

**What:** `topdown=True`, mutate `dirnames[:]` in place to prune `.git` and every subdirectory
that itself holds a `dossier.yaml`.
**Why:** `[VERIFIED: os.walk.__doc__ from the local interpreter — "When topdown is true, the
caller can modify the dirnames list in-place (e.g., via del or slice assignment), and walk
will only recurse into the subdirectories whose names remain in dirnames; this can be used to
prune the search"]`. Also `[VERIFIED: same docstring — "By default, os.walk does not follow
symbolic links to subdirectories"]`, which is the mitigation for the symlink-loop threat in
§Security Domain.

Prune the child *before* descending (test `(dirpath/child)/"dossier.yaml"` while still in the
parent's iteration, or `continue` at the top of the child's own iteration after clearing
`dirnames[:]`). Both work; the second is what the prototype does and it was verified to leave
a sub-dossier's `.claude/`, its broken outbound filenames and its missing living files all
unreported at the parent level.

Sort `dirnames` and `filenames` in place for deterministic traversal; D-04's final
`findings.sort(key=(path, line, ident))` makes output byte-stable regardless, but a sorted walk
makes debugging output reproducible too.

### Pattern 4: Status-header extraction without a per-format parser (D-07)

**What:** Over the first 10 lines, `re.search` each protocol keyword with the comment syntax
tolerated on both sides:

```python
FIELD_RE = re.compile(
    r"\b(Status|To|Subject|Deadline|Written by|Rules):\s*(.*?)\s*(?:-->)?\s*$"
)
```

`\b` before the keyword absorbs a leading `<!--` or `#`; the optional `-->` absorbs the HTML
comment close. First occurrence of each field wins. Verified against Markdown (`Status: draft`),
HTML-commented (`<!-- Status: draft -->`) and plain-text (`# Status: draft`) headers.

### Pattern 5: Test-harness integration surface

`tests/run.sh` needs no edit `[VERIFIED: tests/run.sh:11 — `for f in "$DIR"/test-*.sh; do`;
tests/run.sh:15 — `if bash "$f" >/tmp/gsd-test-output.$$ 2>&1; then`]`. Dropping
`tests/test-lint.sh` in is sufficient.

`tests/lib.sh` offers exactly this surface `[VERIFIED: tests/lib.sh:8,10-11,17,22,105 and the
helper bodies read this session]`:

| Name | Line | Signature / behaviour |
|------|------|-----------------------|
| `REPO_ROOT` | 8 | `"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"` |
| `TESTS_PASSED` / `TESTS_FAILED` | 10-11 | integers, both `0` |
| `init_py()` | 17 | `echo "$REPO_ROOT/skills/dossier-init/scripts/init.py"` |
| `scratch_repo()` | 22 | `mktemp -d` + `git init -q` + test user config; echoes the path |
| `assert_file` / `assert_dir` / `assert_exec` | — | one path argument |
| `assert_grep REGEX PATH` | — | `grep -q --` (basic regex) |
| `assert_grep_e REGEX PATH` | — | `grep -Eq --` (extended regex) |
| `assert_not_grep REGEX PATH` | — | negation of `assert_grep` |
| `assert_eq EXPECTED ACTUAL LABEL` | — | string comparison, prints the label on failure |
| `finish()` | 105 | prints `PASS n FAIL m`, exits 1 if any failed |

Additive extension (D-27) — recommended shape, mirroring `init_py()` exactly:

```bash
# lint_py — the absolute path to the linter under test. Mirrors init_py()
# (tests/lib.sh:17): the bash harness has no ${CLAUDE_PLUGIN_ROOT} expansion.
lint_py() {
  echo "$REPO_ROOT/scripts/lint.py"
}

# assert_lint DOSSIER EXPECTED_EXIT LABEL — runs the linter once, stores
# stdout in LINT_OUT and stderr in LINT_ERR for the assertions that follow.
assert_lint() {
  local dossier="$1" expected="$2" label="$3" status=0
  LINT_OUT="$(python3 "$(lint_py)" "$dossier" 2>"$dossier.stderr")" || status=$?
  LINT_ERR="$(cat "$dossier.stderr" 2>/dev/null || true)"
  assert_eq "$expected" "$status" "$label"
}

# assert_finding ID LABEL     — the identifier appears in the last lint output
# assert_no_finding ID LABEL  — and no other identifier does (D-29 isolation)
assert_finding()    { case "$LINT_OUT" in *"[$1]"*) TESTS_PASSED=$((TESTS_PASSED+1));; *) echo "FAIL: $2 (no [$1] in lint output)" >&2; TESTS_FAILED=$((TESTS_FAILED+1));; esac; }
assert_no_finding() { case "$LINT_OUT" in *"[$1]"*) echo "FAIL: $2 (unexpected [$1])" >&2; TESTS_FAILED=$((TESTS_FAILED+1));; *) TESTS_PASSED=$((TESTS_PASSED+1));; esac; }
```

`case`/glob rather than `grep` keeps it bash-3.2-safe and avoids a subprocess per assertion.
No existing helper changes signature or behaviour, satisfying D-27.

### Pattern 6: Fixture materialisation (D-28/D-29/D-31)

Recommended, and it resolves F-04:

- **Clean fixture — generate at test time, do not commit the tree.** `tests/test-lint.sh`
  calls `scratch_repo()` then `python3 "$(init_py)" --target "$d" --language en …`, then lints
  `$d`. This *is* D-31's "by running `init.py`", taken to its conclusion; it removes the
  synchronisation risk entirely and sidesteps F-04 (a committed tree silently loses
  `sources/transcripts/`). If the planner prefers a committed readable reference (D-28's
  stated motivation), commit it **in addition** and add a third assertion that the committed
  tree and a freshly generated one have the same `find`-sorted relative file list minus the
  known empty-directory gap — otherwise the committed fixture rots the first time `init.py`
  gains a template.
- **French fixture — commit it (D-28).** It must contain deliberate W1/W2 content that
  `init.py` will never produce, so generation is not an option. Build it as
  `init.py --language fr …` output *plus* a committed overlay of the two or three modified
  files. Include the `fichier` / `hiérarchie` bait lines (P-04) so the word-boundary rule has a
  regression test.
- **Error fixtures — `tests/fixtures/make-lint-fixtures.sh` (D-29).** Take the clean tree path
  as `$1`, `cp -R` it once per class into a single `mktemp -d` parent, inject exactly one
  violation, echo the parent path. One `mktemp -d` (not nine) makes the `trap` cleanup a single
  `rm -rf`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Calendar validity of `YYYY-MM-DD` | A month-length / leap-year table | `datetime.date(y, m, d)` in a `try/except ValueError` | D-09 requires `2026-13-45` to be an error; the stdlib already knows February 29th 2027 does not exist |
| Unicode equivalence of accented names | `.replace("é","e")` tables | `unicodedata.normalize("NFC", text)` | D-11/D-17 name it; macOS writes NFD (P-05, reproduced) |
| JSON parsing for D-25 | A second hand-written parser | `json.loads` | D-25 names it; also the only safe choice (no `eval`) |
| Tree traversal with pruning | `os.listdir` recursion | `os.walk(topdown=True)` + `dirnames[:]` | Pruning is the documented mechanism; hand-rolled recursion re-introduces the symlink-loop risk `os.walk` avoids by default |
| YAML type resolution | A YAML 1.1/1.2 implicit-resolver clone | The D-24 per-field schema | D-24 settled this. Implicit resolution is precisely the "Norway problem": under YAML 1.1 a bare `no` resolves to boolean false `[CITED: yaml.rocks/guides/yaml-11-vs-12]` |
| Quoting user strings on the producer side | A new escaping routine | The existing `yaml_quote()` | `[VERIFIED: skills/dossier-init/scripts/init.py:180-190]` — it already strips control characters below 0x20 and escapes `\` then `"` in that order |
| A test framework | pytest / bats shims | `tests/lib.sh`'s counters + `finish()` | C-6, spec §7 |
| In-place file editing in the fixture generator | `sed -i` | `python3 -c` or write-to-temp-then-`mv` | BSD `sed -i` needs an argument, GNU `sed -i` refuses one (P-11) |

**Key insight:** every rule in this phase is either "the stdlib already decides this" or "the
spec already decided this". The only genuinely novel code is the YAML subset parser, and the
whole point of D-24 is that it be as *dumb* as possible — strings in, strings out, all
judgement in the schema above it.

## Runtime State Inventory

This is not a rename phase, but D-24 changes a **producer** whose output already exists in the
world, so the same question applies: after `init.py` is edited, what still carries the old
bytes?

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — the plugin has no datastore. `dossier.yaml` files scaffolded before this change may contain `language: no` unquoted. Verified: none exist in this repository (`scripts/` does not exist, no `dossier.yaml` is tracked). | None. The D-24 schema reads `no` as `"no"` whether quoted or not (verified), so old files keep working — this is precisely why option D was retained. |
| Live service config | None — the plugin never calls a service. | None. |
| OS-registered state | None. | None. |
| Secrets / env vars | None. | None. |
| Build artifacts / installed packages | `skills/dossier-init/scripts/__pycache__/init.cpython-314.pyc` exists and is `.gitignore`d (`__pycache__/`). It is regenerated on the next run; stale bytecode is not a risk because `run.sh` invokes `python3 <path>` which re-checks mtime. | None, but the plan may add `rm -rf skills/dossier-init/scripts/__pycache__` to any "clean" step for tidiness. |
| **Phase 1 assertions bearing on the producer change** | `tests/test-init-empty.sh` asserts `^language: en$`, `^language: es$`, `^language: "en: draft"$`, `^language: "eninjected: pwned"$`; `tests/test-init-fr.sh:28` asserts `^language: fr$`; `tests/test-init-adopt.sh` and `tests/test-init-pointer.sh` pass `--language en`/`--language fr` only. `tests/golden/adopt-proposal.txt` contains **no YAML at all** (18 `rename:`/`untracked:`/`ignored:` lines). `tests/test-init-empty.sh:291` passes `--status-header 'yes: no'` but asserts **exit 2** (argparse `choices=["required"]` rejects it before serialisation). | **None of these regress.** `en`, `es`, `fr`, `required` are not in the reserved-word set, and the two injection assertions already expect the quoted path. D-24's measured regression cost is **confirmed correct**: 0 goldens to regenerate. |

## Common Pitfalls

### P-01 — The linter fails its own freshly scaffolded dossier (the phase's sharpest risk)

**What goes wrong:** `outbound/README.md` fires E1/E2/E3/E4 and the seven living files fire W2.
**Why it happens:** `templates/en/README-outbound.md` and `templates/fr/README-outbound.md`
both quote the status header **verbatim inside a fenced code block**, including
`Status: draft | reviewed by <name> | sent <date time> by <name>` and
`Deadline: YYYY-MM-DD          (optional: when the draft has to be sent)`
`[VERIFIED: the rendered file at <scaffold>/outbound/README.md, read this session]`. And
`README.md` does not match `YYYY-MM-DD_slug`.
**How to avoid:** D-06's exemption, implemented as *both* `README.md` at the root of `sources/`,
`dossier/` and `outbound/` **and** the `.gitkeep` skip. Verified: with the exemption, both
scaffolds print `0 error(s), 0 warning(s)`.
**Warning signs:** any lint run over a fresh `init.py` output that is not exactly
`0 error(s), 0 warning(s)`.

### P-02 — W2 scoped to `dossier/**` instead of the seven living files

**What goes wrong:** 7 spurious W2 warnings per language on a fresh scaffold.
**Why:** `dossier/README.md` contains exactly 7 unsourced bullet lines
`[VERIFIED: grep -c "^- " on the rendered dossier/README.md in both languages this session
→ 7 and 7]`. D-13/D-18 restrict W2 to `ACTORS.md HISTORY.md LEARNINGS.md TONE.md CHANNELS.md
OPEN-QUESTIONS.md RELATIONSHIP.md`; `README.md` is not one of them.
**How to avoid:** iterate the explicit `LIVING_FILES` tuple, never `Path("dossier").glob("*.md")`.
**Warning signs:** `0 error(s), 7 warning(s)` on a clean fixture.

### P-03 — The commented example lines are counted as bullets

**What goes wrong:** every living file has an example fact line; if it counted, W2 would fire.
**Why it does NOT, today:** the templates ship each example as a *whole-line* HTML comment —
`<!-- - Example: Jane Doe (Acme) asks for the deliverable by 2026-10-01 (call @12:34). -->`
`[VERIFIED: <scaffold>/dossier/ACTORS.md and HISTORY.md, read this session]`. After
`line.strip()` the line starts with `<!--`, not `- `, so a naive implementation already skips
it. **Do not rely on that accident.** Implement the comment tracker D-18 asks for (a depth
counter over `<!--` / `-->` per line), because a human writing

```
<!--
- Example: …
-->
```

produces a multi-line comment. Measured: the shipped templates contain **zero** multi-line
HTML comments today, so the tracker has no fixture unless the plan writes one — add one to the
French fixture.

### P-04 — `hier` inside `fichier`: the word-boundary rule is load-bearing for French

**What goes wrong:** W1 fires 3 times on a *clean* French scaffold.
**Why:** `hier` (D-21) is a substring of `fichier`, `fichiers` and `hiérarchie`, and
`dossier/README.md` in French uses `fichier(s)` three times `[VERIFIED: substring count over
the rendered French scaffold this session → 3]`.
**How to avoid:** the boundary class (Pattern 2). Measured with boundaries: **zero** W1 hits on
both clean scaffolds. Equivalent English traps exist for `today`, `soon`, `recently` — measured
substring counts on the English scaffold: 0, 0, 0, so English gives you no early warning.
**Warning signs:** a clean French fixture producing warnings.

### P-05 — NFD on macOS makes accented confidential names invisible

**What goes wrong:** `Sécurité` written by a macOS editor is stored decomposed
(`e` + U+0301); a pattern built from the NFC form in `dossier.yaml` does not match.
**Reproduced this session:** a file written with an NFD name and NFD body came back from
`Path.iterdir()` still NFD (`unicodedata.is_normalized("NFC", name)` → `False` on this APFS
volume); matching the NFC pattern against the raw content → `False`; against
`normalize("NFC", content)` → `True`.
**How to avoid:** normalise **both sides** — the needle from `dossier.yaml` and the haystack
(content *and* filename) — with `unicodedata.normalize("NFC", …)`, exactly as D-11 says.
**Also normalise the typographic apostrophe.** The French word list contains `aujourd'hui` and
`peut-être` with ASCII `'`; the shipped French templates use ASCII `'` throughout (zero U+2019
`[VERIFIED: grep -c for U+2019 over skills/dossier-init/templates/fr/*.md → 0 matches]`), but a
human typing in a smart-quotes editor writes `aujourd’hui` (U+2019) and W1 silently misses it.
Recommendation: `text.replace("’", "'")` immediately after the NFC normalisation.

### P-06 — `Deadline:`/`Status:` picked up from anywhere in the file

**What goes wrong:** a mail body quoting a previous message's header fires E2/E3.
**How to avoid:** D-07's "first 10 lines" window, and first-occurrence-wins per field.

### P-07 — E5 crashes or silently skips on a binary under `outbound/`

**What goes wrong:** `Path.read_text(encoding="utf-8")` raises `UnicodeDecodeError` on a real
`.pdf`/`.docx`, aborting the whole run.
**How to avoid:** a single `read_text()` helper wrapping `UnicodeDecodeError` and `OSError` and
returning `None`; skip the *text* half of E5 for a file that will not decode but still run the
*filename* half. D-07 already excludes binaries from E1/E2/E3 by extension, but E5 is not
extension-scoped and a `.zip` or an image is not in D-07's list.

### P-08 — Exit-code collisions

`lint.py` must return exactly `0` (no errors), `1` (≥1 error), `2` (no `dossier.yaml`). Three
traps: an uncaught exception yields Python's `1`, colliding with "has errors"; `sys.exit("msg")`
prints to stderr **and returns 1**; `argparse`'s own usage error also exits `2`, which happens
to agree with D-02 but for a different reason — document it rather than discover it. Wrap
`main()` so an unexpected exception prints `error: …` on stderr and returns a distinct code
(recommended: `3`) rather than masquerading as a lint failure.

### P-09 — Mentioning `lint.py` in the init skill breaks a Phase 1 test

**What goes wrong:** `bash tests/run.sh` fails on `test-skill-shape.sh`, with no obvious link
to this phase's work.
**Why:** `[VERIFIED: tests/test-skill-shape.sh:73-74 —
`OUT_OF_SCOPE_COUNT=$(grep -ci -E 'stop hook|lint\.py|hooks\.json|marketplace\.json|commands/' "$SKILL_MD")`
followed by `assert_eq 0 "$OUT_OF_SCOPE_COUNT" 'no mention of the Phase 2 linter, hooks.json,
marketplace.json or a commands/ folder'`]`. Adding "and then run `lint.py`" to
`skills/dossier-init/SKILL.md` — a very natural instinct now that the linter exists — turns
that assertion red.
**How to avoid:** do not touch `skills/dossier-init/SKILL.md` in this phase. The linter is
wired into skills in Phases 3/5/6, and that test will have to be relaxed *then*, deliberately.

### P-10 — bash 3.2 on macOS

`/bin/bash` is `3.2.57(1)-release` on this machine and `tests/run.sh:15` invokes plain
`bash "$f"`, so the new test file runs under 3.2. **Forbidden:** associative arrays
(`declare -A`), `mapfile`/`readarray`, `${var,,}`/`${var^^}`, `&>>`, `**` globstar,
`[[ =~ ]]` with `BASH_REMATCH` capture groups beyond basic use. The five Phase 1 test files
already respect this; copy their style.

### P-11 — `sed -i` is not portable

BSD `sed` (macOS, confirmed: `sed --version` is unrecognised) requires `sed -i ''`; GNU `sed`
requires `sed -i` with no argument. The fixture generator must inject its violations with
`python3 - <<'PY'`, `printf > file`, or write-to-temp-then-`mv`. Never `sed -i`.

### P-12 — `mktemp -d` and cleanup

`mktemp -d` returns `/var/folders/…` on macOS, which is a symlink to `/private/var/folders/…`
(measured). This is harmless because every printed path is relative to the dossier root, but a
test that compares an absolute path against `pwd -P` output will fail. Cleanup: `make-adopt-fixture.sh`
does **not** clean up after itself — it echoes the path and the caller is responsible
`[VERIFIED: tests/fixtures/make-adopt-fixture.sh — the script ends with `echo "$d"` and contains
no `trap`]`. Follow the same contract, and have `tests/test-lint.sh` install
`trap 'rm -rf "$FIXTURES"' EXIT` so a failed assertion does not leak nine trees per run.

### P-13 — Upward root discovery escapes the test sandbox

`lint.py` walks upward to `/` with no stop condition (D-01/D-02). A test asserting exit 2 must
run against a path with **no** `dossier.yaml` anywhere up to `/` — `mktemp -d` on macOS
(`/var/folders/…`) satisfies this today, but a developer with a `dossier.yaml` in `$HOME` would
see the test pass for the wrong reason or fail mysteriously. Assert on the stderr text too
(`no dossier.yaml found from … upward`), not the exit code alone. See also Open Question Q-4.

### P-14 — Python 3.8 compatibility

`init.py` declares "Python 3 standard library only, targeting Python >= 3.8"
`[VERIFIED: skills/dossier-init/scripts/init.py:16]`; the machine runs 3.14.6, which will
happily accept 3.9+/3.10+ syntax that a user on 3.8 cannot. Avoid: `str.removeprefix` /
`removesuffix` (3.9+), `Path.is_relative_to` (3.9+, use `try: p.relative_to(r) except
ValueError`), dict `|` merge (3.9+), `match` statements (3.10+), `X | Y` type unions in
annotations without `from __future__ import annotations` (3.10+). Nothing in the design needs
them.

### P-15 — The `1`/`0` scalars in D-24's `consent_recorded` rule

D-24 lists `1|0` among the values that must be an **error** for `consent_recorded`. Note that
`re.fullmatch(r"[-+]?[0-9]+")` — the `staleness_days` rule — would happily accept them; keep
the two rules in separate functions so `1` never leaks into the boolean path.

## Code Examples

All examples below were executed this session against the real scaffold output.

### Example 1 — Quote-aware `#` comment stripping (D-24.1)

```python
def strip_comment(line):
    """Remove an end-of-line `#` comment, respecting quoted scalars.

    spec Sec3.2 shows end-of-line comments on real dossier.yaml lines
    (`language: fr    # language of the dossier content`), and
    consent_source legitimately contains a `#`. A `#` only opens a comment
    when it is outside a quoted scalar AND at the start of the line or
    preceded by whitespace.
    """
    out = []
    quote = None
    for i, ch in enumerate(line):
        if quote:
            out.append(ch)
            if ch == quote:
                quote = None
            continue
        if ch in "\"'":
            quote = ch
            out.append(ch)
            continue
        if ch == "#" and (i == 0 or line[i - 1] in " \t"):
            break
        out.append(ch)
    return "".join(out).rstrip()
```

Verified against the spec §3.2 sample plus `consent_source: "mail 2026-09-16 # from Jane"   # the real source`
→ parsed value `'mail 2026-09-16 # from Jane'`, zero skipped lines.

### Example 2 — The quotedness-preserving scalar and the per-field schema (D-24.2, F-01)

```python
class Scalar:
    """One dossier.yaml scalar, with the two facts the schema needs.

    `quoted` is what makes D-24's consent_recorded rule expressible: the
    parser unquotes (D-24.1) but must not forget that it did, or
    `consent_recorded: "true"` becomes indistinguishable from
    `consent_recorded: true` -- the silent coercion D-24 forbids.
    """
    __slots__ = ("text", "quoted", "line")

    def __init__(self, text, quoted, line):
        self.text, self.quoted, self.line = text, quoted, line


TRUE_SCALARS = frozenset(("true", "True", "TRUE"))     # YAML 1.2 Core Schema
FALSE_SCALARS = frozenset(("false", "False", "FALSE"))


def as_str(scalar, default=""):
    """D-24.2: str verbatim, whatever the spelling. `no` stays "no"."""
    return default if scalar is None else scalar.text


def as_bool(scalar, field, errors):
    """D-24.2: only an UNQUOTED YAML 1.2 Core Schema boolean. Never coerce."""
    if scalar is None:
        return False
    if scalar.quoted or scalar.text not in TRUE_SCALARS | FALSE_SCALARS:
        errors.append((scalar.line,
                       "%s must be an unquoted boolean: true or false" % field))
        return False                       # every ambiguity resolves strict
    return scalar.text in TRUE_SCALARS
```

Measured behaviour:

| `dossier.yaml` line | `Scalar` | `as_bool` | error raised |
|---------------------|----------|-----------|--------------|
| `consent_recorded: true` | `('true', quoted=False)` | `True` | — |
| `consent_recorded: TRUE` | `('TRUE', quoted=False)` | `True` | — |
| `consent_recorded: false` | `('false', quoted=False)` | `False` | — |
| `consent_recorded: "true"` | `('true', quoted=True)` | `False` | yes ✅ |
| `consent_recorded: 'true'` | `('true', quoted=True)` | `False` | yes ✅ |
| `consent_recorded: yes` | `('yes', quoted=False)` | `False` | yes ✅ |
| `language: no` | `('no', quoted=False)` | — | `as_str` → `'no'` ✅ |
| `language: "no"` | `('no', quoted=True)` | — | `as_str` → `'no'` ✅ |

Without the `quoted` flag, rows 4 and 5 returned `True` with no error — confirmed by running
the naive version.

### Example 3 — The JSON adapter (D-25)

```python
def json_to_scalars(obj):
    """Map json.loads output onto the same Scalar representation.

    JSON has real booleans and numbers where the YAML branch has raw text,
    and no line numbers at all. Mapping both branches onto one shape means
    apply_schema() has exactly one code path (D-24.2), and JSON's
    `"consent_recorded": "true"` is rejected for the same reason YAML's is.
    """
    def convert(value):
        if isinstance(value, bool):
            return Scalar("true" if value else "false", False, 0)
        if isinstance(value, int):            # bool is a subclass -- order matters
            return Scalar(str(value), False, 0)
        if isinstance(value, float):
            return Scalar(repr(value), False, 0)
        if value is None:
            return Scalar("", False, 0)
        if isinstance(value, str):
            return Scalar(value, True, 0)     # JSON strings are always quoted
        if isinstance(value, list):
            return [convert(item) for item in value]
        if isinstance(value, dict):
            return {k: convert(v) for k, v in value.items()}
        return Scalar(str(value), True, 0)
    return {k: convert(v) for k, v in obj.items()}
```

Verified: `{"version":1,"language":"no","consent_recorded":true,"staleness_days":7,
"confidential_names":["Acme"]}` → `version` 1, `language` `'no'`, `consent_recorded` `True`,
`staleness_days` 7, names `['Acme']`; and `{"consent_recorded":"true"}` → error, same message
as the YAML branch. **`isinstance(value, bool)` must be tested before `isinstance(value, int)`**
— `bool` is a subclass of `int` in Python.

Detection (D-25): `if raw.lstrip()[:1] == "{": json branch`. Verified on real `json.dumps`
output. Findings against a JSON config carry line `0`; state that in the docstring.

### Example 4 — The nine error injections, each proven to fire alone

These are exactly the injections `make-lint-fixtures.sh` should perform, each on a copy of the
clean tree. The right-hand column is the **measured** prototype output.

| ID | Injection | Measured output |
|----|-----------|-----------------|
| E1 | `outbound/mails/2026-09-17_relance.md` with a body but no header | `outbound/mails/2026-09-17_relance.md:0: ERROR [E1] no status header in the first 10 lines` |
| E2 | header with `Status: sent 2026-09-17` (no ` by <name>`) | `…:1: ERROR [E2] sent status without an absolute date or a sender` |
| E3 | header with `Deadline: next week` | `…:4: ERROR [E3] Deadline: is not an absolute date` |
| E4 | valid header, filename `Relance_Finale.md` | `outbound/mails/Relance_Finale.md:0: ERROR [E4] filename does not match YYYY-MM-DD_slug.ext` |
| E5 | valid header + body line `Nous travaillons avec Acme.` | `…:6: ERROR [E5] confidential name 'Acme' under outbound/` |
| E6 | `consent_recorded: false` → `true` (source stays `""`) | `dossier.yaml:9: ERROR [E6] consent_recorded: true with an empty consent_source` |
| E7 | delete the `Last updated:` line from `dossier/TONE.md` | `dossier/TONE.md:0: ERROR [E7] no Last updated: line` |
| E8 | `mkdir -p dossier/.claude` + a file inside | `dossier/.claude:0: ERROR [E8] .claude/ folder below the dossier root` |
| E9 | `outbound/deliverables/2026-09-17_audit.pdf` with no `.md`/`.html` sibling | `…:0: ERROR [E9] rendered deliverable without its .md/.html source` |

Every one produced `1 error(s), 0 warning(s)` and exit 1 — **perfect isolation, no class
contaminated another**. That is the empirical basis for D-29's "the expected ID fires **and**
no other error ID fires" assertion pair.

### Example 5 — The French warning fixture (ROADMAP criterion 3)

Overlay appended to a `--language fr` scaffold:

```markdown
<!-- appended to dossier/HISTORY.md -->
- Jane Doe (Acme) rappelle demain pour valider le périmètre.
- Le livrable est attendu la semaine prochaine (appel @12:34).
- Probablement un budget revu à la hausse.
- Leur priorité est reconstruite à partir de leurs questions, reconstruit.

<!-- appended to dossier/CHANNELS.md — the word-boundary bait, P-04 -->
- Les fichiers de la hiérarchie sont classés par canal (mail 2026-09-16 de Jane).

<!-- appended to knowledge/CONTEXT.md -->
Le marché a bougé récemment.
```

Measured output — `0 error(s), 4 warning(s)`, exit **0**:

```
dossier/HISTORY.md:19: WARNING [W1] relative-date word 'demain'
dossier/HISTORY.md:19: WARNING [W2] bullet line without a parenthetical source
dossier/HISTORY.md:20: WARNING [W1] relative-date word 'la semaine prochaine'
knowledge/CONTEXT.md:23: WARNING [W1] relative-date word 'récemment'
```

Four behaviours proven at once: W1 fires in both `dossier/` and `knowledge/` (D-17); W2 fires
only on the unsourced bullet; the opinion markers `Probablement` and `reconstruit` **suppress**
W2 on their lines (D-18) while `reconstruite` correctly does *not* satisfy the boundary; the
`fichiers`/`hiérarchie` line produces **no** W1 (P-04) and no W2 (it is sourced); exit stays 0;
and E7 never fires, i.e. the English `Last updated:` label is still found in a French dossier
(C-3 / ROADMAP criterion 3).

### Example 6 — Both Phase 1 debts, reproduced verbatim

Debt (a) — run against the real `init.py`, one fresh `git init` per word:

```
$ python3 skills/dossier-init/scripts/init.py --target <fresh> --language no
$ grep '^language' <fresh>/dossier.yaml
language: no
```

All eight reserved words reproduce: `yes → language: yes`, `on → language: on`,
`off → language: off`, `true → language: true`, `false → language: false`,
`null → language: null`, `y → language: y`, `n → language: n`.

Debt (b) — argv with a real trailing newline (bash `$'en\n'`, or `subprocess` with `"en\n"`):

```
1:[# dossier.yaml]
2:[version: 1]
3:[language: en]
4:[]                 ← the blank line debt (b) describes
5:[counterparts:]
```

And the regex itself:

```python
>>> re.compile(r"^[A-Za-z][A-Za-z0-9_-]*$").match("en\n")   # today: init.py:222
<re.Match object; span=(0, 2), match='en'>                  # → passes the allowlist
>>> re.fullmatch(r"[A-Za-z][A-Za-z0-9_-]*", "en\n")         # D-24 point 3
None                                                        # → routed to yaml_quote()
```

The current producer code, verbatim:

```python
# skills/dossier-init/scripts/init.py:211
_SAFE_PLAIN_SCALAR_RE = re.compile(r"^[A-Za-z][A-Za-z0-9_-]*$")

# skills/dossier-init/scripts/init.py:222 (inside emit_scalar)
    text = value if _SAFE_PLAIN_SCALAR_RE.match(value) else yaml_quote(value)
```

The minimal D-24.3 edit (two lines, one constant):

```python
# YAML 1.1 reserved words (ROADMAP debt (a)): a bare `no` is read as boolean
# false by a strict YAML 1.1 parser -- the "Norway problem". Routed to
# yaml_quote() so `--language no` emits `language: "no"`. This is a
# serialisation rule, not typing: lint.py's per-field schema (Phase 2, D-24)
# is the single place that decides a field's type.
_YAML_RESERVED_SCALARS = frozenset(
    ("y", "n", "yes", "no", "on", "off", "true", "false", "null", "~")
)


def emit_scalar(key, value):
    if (re.fullmatch(_SAFE_PLAIN_SCALAR_PATTERN, value)          # debt (b)
            and value.casefold() not in _YAML_RESERVED_SCALARS): # debt (a)
        text = value
    else:
        text = yaml_quote(value)
    return "{}: {}".format(key, text)
```

Note `~` is in the set for completeness but cannot match `_SAFE_PLAIN_SCALAR_RE` anyway (it
requires a leading letter) — harmless, and it documents intent.

### Example 7 — D-03 sub-dossier boundary, measured

Given a clean dossier containing `clients/other/dossier.yaml`, plus inside that sub-dossier a
`.claude/` directory, an `outbound/mails/BADNAME.md`, and no living files at all:

```
$ python3 lint.py <root>
0 error(s), 0 warning(s)          exit 0   ← the sub-dossier is invisible

$ python3 lint.py <root>/clients/other
dossier/ACTORS.md:0: ERROR [E7] living file is missing
… (7 × E7)
outbound/mails/BADNAME.md:0: ERROR [E1] no status header in the first 10 lines
outbound/mails/BADNAME.md:0: ERROR [E4] filename does not match YYYY-MM-DD_slug.ext
9 error(s), 0 warning(s)          exit 1   ← nearest wins
```

Note the sub-dossier's own `.claude/` did **not** fire E8 in the second run either, because it
sits at exactly `<its own root>/.claude` (D-14). Both halves of D-03 verified.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| YAML 1.1 implicit booleans (`yes`/`no`/`on`/`off`) | YAML 1.2 Core Schema: only `true`/`false` (plus `True`/`TRUE`/`False`/`FALSE`) | YAML 1.2 (2009); tooling migrated much later | Exactly D-24's `consent_recorded` rule. `[CITED: yaml.rocks/guides/yaml-11-vs-12 — "In YAML 1.2 Core Schema, 'yes', 'no', 'on', 'off', 'y', and 'n' are not part of the boolean list"]` |
| `yaml.load()` | `yaml.safe_load()` / no YAML library at all | CVE-era, PyYAML 5.1 warning | Moot here (C-5 forbids the library) but relevant to the *reason*: a hand-written subset parser has no deserialisation attack surface by construction |
| Ad-hoc `sys.exit(1)` for everything | Distinct codes for "has findings" vs "cannot run" | — | D-02's three-code contract; P-08 |
| `os.path.walk` (removed) | `os.walk` with `dirnames[:]` pruning | Python 3.0 | The only supported pruning idiom `[VERIFIED: os.walk.__doc__]` |

**Deprecated/outdated — do not use:**

- `PyYAML` / `ruamel.yaml` / any vendored YAML file: forbidden (C-5).
- `imp`, `distutils`: removed in 3.12; not needed here anyway.
- `datetime.utcnow()` (deprecated 3.12): if `lint.py` ever needs "today" it does not — no check
  in this phase compares a date to the present. `dossier-status` (Phase 6) will, not this.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `re.fullmatch(r"[-+]?[0-9]+")` applied to `staleness_days` should run on the **unquoted** text, so `staleness_days: "7"` is accepted rather than an error | Open Question Q-2 | Low — a stricter reading makes a hand-quoted integer an error, which is noisy but not dangerous. D-24 says "on the raw scalar" without settling quotedness for this field |
| A2 | An **absent** `version` key is not an error (D-24 only constrains a present one) | Open Question Q-3 | Low — `init.py` always writes `version: 1`; the risk is only for hand-written files |
| A3 | Finding identifiers for configuration errors should be `C1` (not folded into E6, not `E10`) | Open Question Q-1 | Medium — this is the tests' assertion surface (D-05 reversibility: "costly"), so it should be chosen deliberately, once |
| A4 | The `outbound/README.md` exemption (D-06) applies to E1–E4 but **not** to E5: a confidential name in the outbound README is still a leak | Open Question Q-5 | Medium — D-06 says "ignored by the outbound checks" without enumerating; the shipped templates contain no confidential name, so no fixture disambiguates it |
| A5 | `lint.py` will exceed the 300-line global file-size guard and will carry a `vibeflow:allow-large-file` marker like `init.py` | Open Question Q-6 | Low mechanically, but it opens a third Broken Window (two are already open, `.planning/WINDOWS.md`) |
| A6 | Rendered-binary extensions for D-07's exclusion are `.pdf .docx` plus images (`.png .jpg .jpeg .gif .webp`) and office formats (`.odt .pptx .xlsx`) | Architecture Patterns | Low — an unlisted binary reaches the decoder and is skipped by P-07's guard rather than crashing |
| A7 | `tests/test-lint.sh` should assert stderr text for the exit-2 case, not just the code | P-13 | Low |

## Open Questions

1. **Q-1 — Which identifier do configuration errors carry?**
   - What we know: D-05 defines `E1`…`E9`, `W1`, `W2`. D-24.2 mandates four *new* error
     conditions that are not in that list: `version` not 1, `staleness_days` not a positive
     integer, `consent_recorded` not an unquoted boolean, and (D-22) an unparseable line.
     D-24.4 explicitly requires fixtures for `consent_recorded: yes` and
     `consent_recorded: "true"` exiting 1 "with a message naming the field" — so they must be
     assertable, so they must have an identifier.
   - What's unclear: whether to extend the ladder (`E10`, `E11`), reuse `E6` (the only other
     `dossier.yaml`-scoped error), or open a separate namespace.
   - **Recommendation:** open a separate namespace — `C1` for "configuration error"
     (`dossier.yaml` is malformed or a field is mistyped), and `C0` as a WARNING for D-22's
     "unknown or unparseable line skipped". Rationale: (a) the ROADMAP's count of "nine error
     classes" stays exactly nine, so criterion 2 is not silently redefined; (b) `E10`/`E11`
     would imply they are dossier-content errors, which they are not; (c) a distinct namespace
     lets a future `dossier-status` distinguish "your config is broken" from "your dossier has
     drifted" without parsing prose. Both `C1` and `E*` count toward exit 1.

2. **Q-2 — Is `staleness_days: "7"` an error?**
   - What we know: D-24.2 says "int via `re.fullmatch(r"[-+]?[0-9]+")` on the raw scalar".
   - What's unclear: "raw scalar" could mean before or after unquoting.
   - **Recommendation:** accept it (run the regex on `.text`, ignore `.quoted`). Unlike
     `consent_recorded`, `staleness_days` gates nothing — it is a `dossier-status` threshold —
     so the strict-on-ambiguity rule D-24 states for `consent_recorded` does not transfer.
     Document the asymmetry in a comment so the next reader does not "fix" it. Still error on
     a non-integer and on `≤ 0`, per D-24.

3. **Q-3 — Is an absent `version` an error?**
   - **Recommendation:** no. Treat absent as "assume 1". `init.py` always emits `version: 1`
     `[VERIFIED: skills/dossier-init/scripts/init.py:254 — `lines = ["# dossier.yaml",
     "version: 1", …]`]`, so an absent one only happens in a hand-written or JSON config, and
     failing it gains nothing. A *present* `version: 2` remains "dossier.yaml unreadable" per
     D-24.

4. **Q-4 — Should the upward walk stop at a boundary?**
   - What we know: D-01 says "walks **upward** to the nearest `dossier.yaml`", with no stop
     condition. On a developer machine, that can escape the repository and find an unrelated
     dossier in `$HOME`.
   - **Recommendation:** implement D-01 literally (no stop condition) — a dossier legitimately
     lives inside a larger repository and stopping at `.git` would break that. Mitigate in the
     tests (P-13) rather than in the linter, and note the behaviour in the `--help` text.

5. **Q-5 — Does the README exemption cover E5?**
   - What we know: D-06 says `README.md` "is ignored by the outbound checks". D-11 says
     confidential names are searched in "every file under `outbound/`".
   - **Recommendation:** exempt `outbound/README.md` from E1–E4 only; keep E5 active on it. A
     leaked name is a leak wherever it sits, the templates contain none so the clean fixture is
     unaffected, and the narrower exemption is the one that cannot cause harm. Add a
     `make-lint-fixtures.sh` variant that puts `Acme` into `outbound/README.md` and asserts E5
     fires, so the decision is pinned by a test rather than by prose.

6. **Q-6 — Single-file `lint.py` vs. the 300-line guard.**
   - What we know: a 285-line prototype implements everything with terse comments; production
     quality (docstrings explaining *why*, per `init.py`'s convention) lands around 400–500
     lines. A global vibeflow hook flags files over 300 lines; `init.py` already carries
     `# vibeflow:allow-large-file` and that is **open Broken Window #2**
     `[VERIFIED: .planning/WINDOWS.md, row 2 — "Global vibeflow 300-line file-size guard hook
     (not part of this project) forced tracing debt via vibeflow:allow-large-file marker"]`.
   - **Recommendation:** keep `lint.py` a single file and carry the marker with a rationale
     naming DIST-03 (bare-skills installs copy `scripts/` wholesale and consumers invoke the
     script by path; a second importable module makes `sys.path` a distribution concern).
     Record the new window deliberately in the plan rather than discovering it at execution.
     Splitting is a Phase 7 conversation, alongside the other manifest work.

7. **Q-7 — Does the committed clean fixture stay in sync? (F-04)**
   - What we know: `init.py` writes `.gitkeep` into exactly seven leaves
     `[VERIFIED: skills/dossier-init/scripts/init.py:48-56, GITKEEP_LEAVES — "sources/received",
     "sources/transcripts/raw", "knowledge/decisions", "knowledge/watch",
     "outbound/deliverables", "outbound/mails", "outbound/calls"]` but creates twelve
     directories `[VERIFIED: init.py:28-40, FOLDERS]`. `sources/transcripts/` therefore contains
     only the `raw/` subdirectory and no `.gitkeep`. Committing the scaffold to git tracks 21
     files and **loses nothing visible** — but a `git clone` reconstructs `sources/transcripts/`
     only because `raw/.gitkeep` forces its parent to exist. Measured: `git ls-files` after
     `git add -A` shows `fixture/sources/transcripts/raw/.gitkeep` and no entry for
     `sources/transcripts` itself.
   - **Recommendation:** this specific case is benign, but it demonstrates the class of drift
     D-31 exists to prevent. Generate the clean fixture at test time from `init.py`
     (Pattern 6). If D-28's committed tree is kept for readability, add an assertion comparing
     the two file lists so drift is loud.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `python3` | `scripts/lint.py`, every test | ✓ | 3.14.6 (`v3.14.6:c63aec69bd5`) | — (hard requirement; target ≥ 3.8 per P-14) |
| `bash` | `tests/run.sh`, `tests/test-lint.sh`, `make-lint-fixtures.sh` | ✓ | 3.2.57(1)-release, `/bin/bash` | — (and P-10 constrains the dialect) |
| `git` | `scratch_repo()` in `tests/lib.sh` | ✓ | present (used by the green Phase 1 suite) | — |
| `mktemp -d` | `scratch_repo()`, `make-lint-fixtures.sh` | ✓ | BSD, returns `/var/folders/…` | — |
| `cp -R` | fixture cloning | ✓ | BSD | `python3 -c "shutil.copytree(...)"` if a `-a`/`--preserve` difference ever bites |
| `grep` | `tests/lib.sh` assertions | ✓ | BSD grep; `-P` happens to be available but **do not use it** (not portable to stock Linux BSD-free images either way) | `case`/glob in bash (recommended for the new helpers) |
| `sed` | — | ✓ | BSD (`sed --version` unrecognised) | **Do not use `sed -i`** (P-11); use `python3` or `printf` |
| `readlink -f` | — | ✓ | available on this macOS | Not needed; use `pathlib.Path.resolve()` inside Python |
| `pdftotext` | *Phase 4 only* | not checked | — | Out of scope here; STATE.md already tracks it as a Phase 4 concern |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** none.

**Baseline measured this session:** `bash tests/run.sh` → `TOTAL: 5 files, 0 failed`
(`test-init-adopt.sh`, `test-init-empty.sh`, `test-init-fr.sh`, `test-init-pointer.sh`,
`test-skill-shape.sh` all `ok`). Any regression is attributable to this phase's changes.

**Note:** `scripts/` does not exist at the repository root yet — the plan's first task creates
it `[VERIFIED: `ls -d scripts` → no such directory, this session]`.

## Validation Architecture

`workflow.nyquist_validation` is `true` in `.planning/config.json`, so this section is required.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | bash 3.2 + python3 3.8+, hand-rolled assertions in `tests/lib.sh` (no third-party framework — C-6, spec §7) |
| Config file | none — `tests/run.sh` is the dispatcher and needs no config |
| Quick run command | `bash tests/test-lint.sh` |
| Full suite command | `bash tests/run.sh` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| LINT-01 | Clean scaffold → exit 0, zero findings (ROADMAP crit. 1) | integration | `bash tests/test-lint.sh` | ❌ Wave 0 |
| LINT-01 | Each of E1…E9 fires, and **only** it (ROADMAP crit. 2) | integration | `bash tests/test-lint.sh` | ❌ Wave 0 |
| LINT-01 | French fixture → exit 0 with W1+W2, English `Last updated:` found (crit. 3) | integration | `bash tests/test-lint.sh` | ❌ Wave 0 |
| LINT-01 | No `dossier.yaml` upward → exit 2 + stderr text (D-02) | integration | `bash tests/test-lint.sh` | ❌ Wave 0 |
| LINT-01 | Sub-dossier is a boundary (D-03) | integration | `bash tests/test-lint.sh` | ❌ Wave 0 |
| LINT-01 | Output sorted by path then line, stable across two runs (D-04) | integration | `bash tests/test-lint.sh` (diff two runs) | ❌ Wave 0 |
| LINT-01 | `consent_recorded: yes` and `: "true"` → exit 1, `C1`, field named (D-24.4) | integration | `bash tests/test-lint.sh` | ❌ Wave 0 |
| LINT-01 | JSON fallback under the `dossier.yaml` name parses (D-25) | integration | `bash tests/test-lint.sh` | ❌ Wave 0 |
| LINT-01 | `init.py --language no` → `^language: "no"$` (debt (a), D-24.4) | unit | `bash tests/test-init-empty.sh` (extended) | ✓ exists, extend |
| LINT-01 | `--language $'en\n'` → no blank line after the value (debt (b), D-24.4) | unit | `bash tests/test-init-empty.sh` (extended) | ✓ exists, extend |
| LINT-01 | Round-trip `init.py --language no` → `lint.py` parser reads `"no"` (D-24.4) | integration | `bash tests/test-lint.sh` | ❌ Wave 0 |
| LINT-02 | Clean + French fixtures exist and are materialisable | integration | `bash tests/test-lint.sh` | ❌ Wave 0 |
| LINT-02 | Nine error fixtures generated at runtime under `mktemp -d` | integration | `bash tests/fixtures/make-lint-fixtures.sh <clean>` | ❌ Wave 0 |
| LINT-03 | The whole suite is green, Phase 1 included | integration | `bash tests/run.sh` → `TOTAL: 6 files, 0 failed` | ✓ dispatcher exists |
| LINT-03 | `scripts/lint.py` is executable and shebanged (Phase 1 convention) | unit | `assert_exec "$(lint_py)"` in `tests/test-lint.sh` | ❌ Wave 0 |

### Sampling Rate

The eleven finding classes plus the four configuration conditions are the signal; the test file
is the sampler. Nyquist here means **at least one assertion pair per class**, and for the error
classes a *pair*, not a single assertion:

- **Per task commit:** `bash tests/test-lint.sh` (and `bash tests/test-init-empty.sh` for any
  task touching `init.py`).
- **Per wave merge:** `bash tests/run.sh` — must print `TOTAL: 6 files, 0 failed`.
- **Phase gate:** `bash tests/run.sh` green **plus** a manual `python3 scripts/lint.py` against
  a freshly `init.py`-scaffolded dossier in both languages, both printing
  `0 error(s), 0 warning(s)`, before `/gsd-verify-work`.

Coverage target, stated as counts so the planner can check it:

| Class | Positive assertion (it fires) | Negative assertion (it does not fire spuriously) |
|-------|-------------------------------|--------------------------------------------------|
| E1…E9 | 9 — one per error fixture | 9 × 10 — for each fixture, assert every *other* identifier is absent (D-29 reason 2) |
| W1, W2 | 2 — on the French fixture | 2 — absent on both clean fixtures |
| C1 (config) | 3 — `consent_recorded: yes`, `: "true"`, `staleness_days: abc` | 1 — absent on both clean fixtures |
| exit codes | 3 — 0 (clean), 1 (each error fixture), 2 (no dossier) | — |

### Wave 0 Gaps

- [ ] `scripts/lint.py` — the subject under test does not exist; `scripts/` itself does not exist
- [ ] `tests/test-lint.sh` — covers LINT-01, LINT-03
- [ ] `tests/fixtures/make-lint-fixtures.sh` — covers LINT-02
- [ ] `tests/fixtures/lint/fr/` — covers LINT-02, ROADMAP criterion 3
- [ ] `tests/lib.sh` additive helpers (`lint_py`, `assert_lint`, `assert_finding`,
      `assert_no_finding`) — covers LINT-03
- [ ] Framework install: **none required** — bash and python3 are present

### Where a test would silently pass while the behaviour is broken

These are the blind spots the plan must close explicitly; each is a real way to get a green
suite and a broken linter.

1. **Asserting only "exit 1" on an error fixture.** Every one of the nine fixtures exits 1 for
   *any* error. Without `assert_finding <ID>`, a linter that reports E7 on all nine fixtures
   passes. → D-30's identifier assertion is not optional; pair it with the nine
   `assert_no_finding` sweeps.
2. **A clean fixture that is not what `init.py` produces.** If the committed tree is
   hand-edited to make the linter pass, criterion 1 becomes a tautology. → Pattern 6 / Q-7.
3. **`consent_recorded: "true"` asserted only on exit code.** Both the correct behaviour
   (C1 config error) and the bug (silent coercion to `true`, then E6 because `consent_source`
   is empty) exit 1 — I hit exactly this with the naive prototype. → assert the **identifier
   and the field name**, not the exit code.
4. **W1/W2 asserted only by count.** A French fixture asserting "4 warnings" passes if W1 fires
   4 times and W2 never does. → assert each identifier present, and assert the *specific* path
   and line where practical.
5. **The `fichier`/`hiérarchie` bait absent from the French fixture.** Without it, a linter with
   no word boundaries passes every test and then floods a real French dossier. → P-04.
6. **The Phase 1 suite not re-run after the `init.py` edit.** `bash tests/test-lint.sh` alone
   cannot see a Phase 1 regression. → D-24's mandated explicit `bash tests/run.sh` task.
7. **Output stability asserted by eyeballing.** D-04's "byte-stable" claim needs two runs
   diffed, not one run read. → one assertion comparing two consecutive invocations.
8. **E5 tested only with a name in the body.** The filename half is a separate code path and is
   exactly the one `(?<!\w)` breaks (F-02). → a fixture named `2026-09-17_acme-offer.md` with a
   clean body.

## Security Domain

`workflow.security_enforcement` is `true`, `security_asvs_level` is `1`.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | The linter has no principal, no credential, no session |
| V3 Session Management | no | No session |
| V4 Access Control | no | No authorisation decision; the linter is read-only and non-privileged |
| V5 Input Validation / Encoding | **yes** | All input is untrusted repository content. Parse with `json.loads` (never `eval`/`exec`/`pickle`); build every regex with `re.escape` on `dossier.yaml`-derived values; escape control characters in every printed path (see below) |
| V6 Cryptography | no | No cryptography anywhere in this phase |
| V7 Error Handling / Logging | **yes** | Distinct exit codes (D-02, P-08); never print file *content*, only the matched needle (which came from `dossier.yaml`, already in the repo) and the location |
| V12 / V13 File & Resource Handling | **yes** | `os.walk(followlinks=False)` (the default); do not follow symlinked files either; cap file size before `read_text`; never write, never `chmod`, never `os.remove` |
| V14 Configuration | **yes** | `consent_recorded` fails closed (D-24's "every ambiguity resolves on the strict side") — an unparseable value must never disable the E5 leak check |

### Known Threat Patterns for a stdlib file-tree linter

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| **Output-line forgery via a crafted filename.** POSIX filenames may contain `\n` and ANSI escapes. A file named `x\n0 error(s), 0 warning(s)` makes `lint.py`'s stdout contain a forged summary line that a grepping consumer (`dossier-status`, Phase 6) believes. | Spoofing / Tampering | Sanitise every printed path: replace characters below 0x20 and 0x7F with their `\xNN` escape before formatting the finding line. One helper, applied in exactly one place (the reporter). |
| **Symlink escape / traversal.** A symlinked directory under `outbound/` pointing at `/` or at `~`. | Information Disclosure / DoS | `os.walk` does not follow directory symlinks by default `[VERIFIED: os.walk.__doc__]`. Additionally skip symlinked *files* (`Path.is_symlink()`) before `read_text`, so a symlink to `~/.ssh/id_rsa` under `outbound/` is never opened. |
| **Symlink loop.** `a → ..` inside the tree. | DoS | Same default; do not pass `followlinks=True`. |
| **Resource exhaustion on a huge file.** `read_text()` on a multi-GB file under `outbound/`. | DoS | `stat().st_size` check before reading; skip with a note above a threshold (5 MB is generous for a dossier). |
| **Deserialisation.** | Tampering / RCE | `json.loads` only. No `eval`, `exec`, `pickle`, `yaml.load`, `importlib` of repository content. The hand-written YAML parser has no object-construction path by design. |
| **ReDoS via `confidential_names`.** A hostile `dossier.yaml`. | DoS | `re.escape` every needle; the resulting pattern is a literal with two lookarounds — no nesting, no backtracking blowup. Never interpolate a config value into a regex unescaped. |
| **Fail-open on a malformed gate.** `consent_recorded: <garbage>` silently disabling E5. | Tampering / Elevation of scope | D-24's strict rule, implemented as Example 2: any non-Core-Schema or quoted value is a `C1` error **and** yields `False`, so the leak check stays on. This is the single most security-relevant line in the phase. |
| **Command injection.** | Elevation | `lint.py` runs no subprocess and does no shell interpolation. Keep it that way — the linter must never call `git`, `grep` or `pdftotext`. |
| **Test-harness path injection.** A fixture path containing spaces or `$`. | Tampering | Every variable in `test-lint.sh` and `make-lint-fixtures.sh` quoted; `grep -- "$regex"` pattern already used in `tests/lib.sh`. |

None of these is high severity for a local, read-only developer tool, and none blocks the phase
(`security_block_on: high`). The output-line forgery and the fail-open gate are the two worth
one explicit test each.

## Sources

### Primary (HIGH confidence)

- `skills/dossier-init/scripts/init.py` — read this session; lines 16, 28-40 (`FOLDERS`),
  48-56 (`GITKEEP_LEAVES`), 62-76 (`TEMPLATE_MAP`), 180-190 (`yaml_quote`), 193-211
  (`_SAFE_PLAIN_SCALAR_RE` + its rationale comment), 214-223 (`emit_scalar`), 247-279
  (`render_dossier_yaml`), 294-298 (`under_root`), 689-723 (argparse)
- `tests/run.sh` (30 lines), `tests/lib.sh` (111 lines), `tests/test-init-empty.sh`,
  `tests/test-init-fr.sh`, `tests/test-skill-shape.sh`, `tests/fixtures/make-adopt-fixture.sh`,
  `tests/golden/adopt-proposal.txt` — all read this session
- `docs/superpowers/specs/2026-09-16-client-dossier-design.md` §3.2, §3.3, §3.4, §4.4, §6, §7
- `.planning/phases/02-linter-test-harness/02-CONTEXT.md`, `.planning/REQUIREMENTS.md`,
  `.planning/STATE.md`, `.planning/WINDOWS.md`, `.planning/config.json`, `CLAUDE.md`,
  `.gitignore`
- **Executed this session:** `init.py` scaffolding an `en` and an `fr` dossier; a 285-line
  prototype linter run against both scaffolds, nine error fixtures, one French warning fixture,
  a nested sub-dossier, a no-dossier path, and three `dossier.yaml` typing cases;
  `bash tests/run.sh` baseline; `git check-ignore -v` on a nested `.claude/`; `re`/`unicodedata`
  boundary and NFC experiments
- `os.walk.__doc__` and `re.__doc__` read from the local CPython 3.14.6 interpreter

### Secondary (MEDIUM confidence)

- YAML 1.1 vs 1.2 boolean resolution ("the Norway problem") — corroborated across
  `yaml.rocks/guides/yaml-11-vs-12`, `github.com/yaml/pyyaml/issues/486`,
  `github.com/oven-sh/bun/pull/25537`. Used only to justify D-24, which is already settled.

### Tertiary (LOW confidence)

- None. Every claim in this document is either in-repo and read this session, executed this
  session, or corroborated by two independent public sources.

## Metadata

**Confidence breakdown:**

- Standard stack: **HIGH** — there is no stack to choose; C-5/C-6 reduce it to the stdlib, and
  every module named was exercised against the real scaffold this session
- Architecture: **HIGH** — the whole design was prototyped and run end to end; the three
  corrections (F-01 quotedness, F-02 boundary class, Q-1 identifier namespace) come from
  observed failures, not from reasoning
- Pitfalls: **HIGH** for P-01…P-05, P-09…P-12 (each reproduced with a measured number);
  **MEDIUM** for P-06, P-07, P-13, P-14 (reasoned from the code and the platform, not
  triggered)
- Security: **MEDIUM** — ASVS L1 mapping is sound for a read-only local tool, but no adversarial
  fixture was run; the two recommended tests (filename forgery, fail-open gate) would raise it

**Research date:** 2026-09-17
**Valid until:** 2026-10-17 — the domain is in-repo and stable; the only invalidating event is a
change to `init.py`'s output bytes or to `tests/lib.sh`'s helper surface, both of which are
under this phase's own control.
