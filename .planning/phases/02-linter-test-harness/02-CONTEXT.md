# Phase 2: Linter & Test Harness - Context

**Gathered:** 2026-09-17
**Status:** Ready for planning

> **Gathered without Samuel online.** Every open choice was settled from the spec, the
> ROADMAP, REQUIREMENTS.md, `CLAUDE.md` or the Phase 1 code, and each one that was a genuine
> product choice is listed in **Assumptions (to be validated by Samuel)** at the end of
> `<decisions>`. Nothing below is presented as Samuel's answer.

<domain>
## Phase Boundary

`scripts/lint.py` (repository root, Python 3 standard library only) plus the fixtures and the
bash test file that prove it. The linter finds the nearest `dossier.yaml`, reads it with a tiny
YAML-subset parser, and runs the eight mechanical checks of spec §4.4 over the dossier tree:
nine error classes (exit 1) and two warning classes (exit 0). It reads the filesystem and
prints findings; it never writes, never fixes, never calls git, never network.

The test side adds `tests/test-lint.sh` (picked up automatically by the existing
`tests/run.sh` dispatcher), additive helpers in `tests/lib.sh`, a committed clean fixture, a
committed French-content fixture, and a runtime generator for the per-error-class fixtures.

Not in this phase: the `dossier` skill and the three hooks (Phase 3), `dossier-ingest`
(Phase 4), `dossier-draft` (Phase 5), `dossier-status` and the `dossier-lint` command
(Phases 6/7), the manifests (Phase 7), any `--fix` mode, any git awareness, any CI wiring.
The later consumers call `lint.py` as a subprocess and read its exit code — that contract is
what this phase must make stable, nothing more.

</domain>

<decisions>
## Implementation Decisions

### Invocation, root discovery, output

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
  improved later without breaking the harness. — **Reversibility:** costly — the identifiers
  become the assertion surface of `tests/test-lint.sh` and, later, of anything that greps lint
  output; renaming one means touching every fixture assertion.
- **D-06:** `.gitkeep` files are ignored everywhere (LINT-01, spec §3.2). `README.md` at the
  root of `sources/`, `dossier/` and `outbound/` is ignored by the outbound checks — **this is
  load-bearing**: the Phase 1 template `templates/en/README-outbound.md` quotes the status
  header verbatim, including the literal `Deadline: YYYY-MM-DD` and `sent <date time> by
  <name>`. Without this exemption every freshly scaffolded dossier fails its own linter.

### The nine error classes (ROADMAP criterion 2) and their mapping

Spec §4.4 lists eight checks; the ROADMAP names nine error classes. The mapping is fixed:

| ID | Error class (ROADMAP criterion 2) | Spec §4.4 | Requirement |
|----|-----------------------------------|-----------|-------------|
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

LINT-02 is the fixture set that makes each of E1…E9 fire at least once plus the clean and
French fixtures; LINT-03 is `tests/test-lint.sh` asserting exit codes and messages.

- **D-07 (E1):** "Outbound file" = every file under `outbound/` except `.gitkeep`, `README.md`,
  and rendered binaries (`.pdf`, `.docx`, images) which cannot carry a text header. The status
  block must appear within the **first 10 lines**; the linter greps the English protocol
  keywords and ignores the comment syntax around them (`<!-- -->`, `#`), so no per-format
  parser is needed. "Complete" (LINT-01) = `Status:`, `To:` and `Written by:` present, plus
  `Subject:` for files under `outbound/mails/`. `Deadline:` and `Rules:` stay optional. —
  Assumption A-02.
- **D-08 (E2):** `Status:` must be `draft`, `reviewed by <non-empty name>`, or
  `sent <YYYY-MM-DD>[ <time>] by <non-empty name>`. An absent date, a relative date, or an
  absent/empty sender is E2. `reviewed by` with no name is E2 as well — same class, it is the
  same defect (an incomplete status value).
- **D-09 (E3):** `Deadline:` value must match `^\d{4}-\d{2}-\d{2}$` **and** be a real calendar
  date (validated with `datetime.date`), so `2026-13-45` is an error, not a pass.
- **D-10 (E4):** Files directly under `outbound/deliverables|mails|calls/` must match
  `^\d{4}-\d{2}-\d{2}_[a-z0-9]+(-[a-z0-9]+)*\.[A-Za-z0-9]+$`, date validated as in D-09.
  Slug charset: lowercase ASCII letters, digits, single hyphens. `.gitkeep` and `README.md`
  exempt. — Assumption A-03.
- **D-11 (E5):** Each entry of `confidential_names` is searched case-insensitively, with word
  boundaries (`(?<!\w)…(?!\w)`, so "Acme" does not fire inside "Acmetal"), in the **text
  content and in the filename** of every file under `outbound/`. Text is normalised with
  `unicodedata.normalize("NFC", …)` before matching so an accented name written NFD (macOS)
  still matches. The whole check is suppressed when `consent_recorded: true` **and**
  `consent_source` is non-empty (spec §3.2).
- **D-12 (E6):** `consent_recorded: true` with an empty or missing `consent_source` is
  reported at `dossier.yaml:<line>` — "a consent without a source is an opinion" (spec §3.2).
- **D-13 (E7):** "Living file" = exactly the seven files under `dossier/` (`ACTORS.md`,
  `HISTORY.md`, `LEARNINGS.md`, `TONE.md`, `CHANNELS.md`, `OPEN-QUESTIONS.md`,
  `RELATIONSHIP.md`). Grounded in Phase 1: those seven templates carry `Last updated:` and
  `knowledge/CONTEXT.md` / `knowledge/DOCTRINE.md` do not. The line must carry an absolute,
  real date. A living file that is **absent** is reported under E7 with its own message. —
  Assumption A-04.
- **D-14 (E8):** Any directory named `.claude` whose path is not exactly `<root>/.claude`.
- **D-15 (E9):** Under `outbound/deliverables/`, a `.pdf` or `.docx` must have a sibling with
  the same stem and a `.html` or `.md` extension. The reverse (a source with no render) is
  fine and silent.

### The warning boundary (what is a heuristic, and therefore never exit 1)

- **D-16:** The dividing line is: a rule a regex can decide with certainty on protocol
  keywords and paths is an **error**; a rule that has to guess at natural language is a
  **warning**. That puts W1 (relative-date words) and W2 (bullet lines with no parenthetical
  source) on the warning side, exactly as spec §4.4 checks 5 and 6 prescribe, and keeps exit 1
  meaning "this dossier is mechanically malformed", never "this prose looks suspicious".
- **D-17 (W1):** Relative-date words are looked for in `dossier/` and `knowledge/` only (spec
  §4.4 check 5), case-insensitively, on NFC-normalised text, with word boundaries.
- **D-18 (W2):** A bullet line (`- ` / `* ` at the start of a stripped line) in one of the
  seven living files must end with a parenthetical source, i.e. match `\([^()]+\)\.?\s*$`.
  Exempt: lines inside an HTML comment (the templates ship their example lines commented out —
  a freshly scaffolded dossier must produce zero warnings), lines that are headings, and lines
  carrying one of the allowed **opinion markers** (spec §4.4 check 6), which is how a
  deliberately unsourced reconstruction is written (spec §3.4).

### Language word lists (data, not protocol keywords)

- **D-19:** The two word lists live in `lint.py` as a single module-level constant
  `LANGUAGE_WORDS = {"en": {...}, "fr": {...}}`, physically separated from — and commented as
  distinct from — the protocol-keyword constants. They are the **only** place the linter knows
  anything about the dossier's language (spec §4.4 closing sentence). No per-language table of
  labels exists or may be added: `Last updated:`, `Status:`, `To:`, `Subject:`, `Deadline:`,
  `Written by:`, `Rules:`, `draft`, `reviewed by`, `sent` are grepped in English in every
  dossier (spec §3.2, `CLAUDE.md`).
- **D-20:** v1 ships `en` and `fr`. Selection is driven by `language:` from `dossier.yaml`; an
  unknown language means W1/W2's marker list is skipped with a single informational line —
  never an error, never a crash.
- **D-21:** v1 word lists (extendable later without a contract change):
  - relative dates `en`: tomorrow, yesterday, today, next week, last week, this week, next
    month, last month, soon, recently, in a few days
  - relative dates `fr`: demain, hier, aujourd'hui, la semaine prochaine, la semaine dernière,
    cette semaine, le mois prochain, le mois dernier, bientôt, récemment, prochainement,
    dans quelques jours
  - opinion markers `en`: reconstructed, I think, probably, it seems, apparently, maybe
  - opinion markers `fr`: reconstruit, je pense, probablement, il semble, apparemment,
    peut-être
  — Assumption A-06.

### `dossier.yaml`: the YAML-subset parser and the JSON fallback

- **D-22:** The parser reads only what the linter needs — `language`, `confidential_names`,
  `consent_recorded`, `consent_source`, `status_header`, `staleness_days`, `date_format` — and
  ignores every other key, including the `counterparts` block it does not use. Supported
  subset: `key: value`, inline lists `[ a, b ]`, block lists `- item`, `#` comments, single
  and double quotes. Unknown or unparseable **lines** are skipped with a warning, not a crash;
  an unreadable file is exit 2 as in D-02.
- **D-23:** Typing fidelity — every string-valued key is read **as a string, whatever its
  spelling**: `language: no` is the string `"no"` (Norwegian), never boolean `False`. This is
  the consumer-side half of the Phase 1 carried-over debt (a). Only `consent_recorded` is read
  as a boolean and only `staleness_days` as an integer. — **Reversibility:** reversible.
- **D-24 (SETTLED 2026-09-17 by the mission manager — supersedes the "open" wording this
  entry carried at context-gathering time).** A research panel compared four options
  (producer-only hardening / consumer-only chain reading / both with implicit YAML 1.2
  resolution / per-field schema). **Retained: option D — per-field typing in `lint.py` (a
  schema) plus a minimal typographic hardening of the producer**, because it concentrates
  typing in ONE place (the `lint.py` schema), leaves the producer a pure serialisation rule,
  and stays robust to a `dossier.yaml` written by hand, by Codex, or by a bare-skills harness.
  The rule, verbatim:

  1. **Parser (`lint.py`)** — always returns **raw strings** (plus lists/dicts for structure):
     unquoting of `"…"`/`'…'`, flow sequences `[ a, b ]`, block sequences of mappings
     (`counterparts`), stripping of `#` comments **quote-aware** (spec §3.2 shows end-of-line
     comments). **No** implicit int/bool/null/float/date conversion at the scalar level.
  2. **Per-field schema, above the parser**:
     - `version` → int (`re.fullmatch(r"[-+]?[0-9]+")`), must equal `1`, otherwise the error
       "dossier.yaml unreadable".
     - `language`, `consent_source`, `timestamps`, `date_format`, `status_header`,
       `counterparts[].name|role`, `counterparts[].contacts[]`, `confidential_names[]` →
       **str verbatim**, whatever the spelling (`no` stays `"no"` — this is the consumer-side
       fix of debt (a)).
     - `staleness_days` → int via `re.fullmatch(r"[-+]?[0-9]+")` on the raw scalar; absent →
       default 7; present and not an integer, or ≤ 0 → an error naming the field.
     - `consent_recorded` → bool, **only** an unquoted YAML 1.2 Core Schema scalar:
       `true|True|TRUE` → true, `false|False|FALSE` → false; absent → false;
       `yes|no|on|off|y|n|1|0` or any quoted form (`"true"`) → **error**
       "consent_recorded must be an unquoted boolean: true or false". **Never** a silent
       coercion to true — this field is the gate that disables the confidential-name leak
       check under `outbound/`; every ambiguity resolves on the strict side.
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

  **Measured regression cost on Phase 1** (by the panel): `emit_scalar()` has only 2 call
  sites (`init.py` ~l.254 `language`, ~l.275 `status_header`), and no assertion in
  `tests/test-init-empty.sh`, `tests/test-init-fr.sh` nor the golden
  `tests/golden/adopt-proposal.txt` bears on a reserved word — ~4 lines of production code
  plus 2-3 new tests, 0 golden to regenerate. The plan must nevertheless carry an explicit
  task "the Phase 1 suite stays green" (`bash tests/run.sh`).

  — **Reversibility:** the producer half is a one-line-scale change; the schema half becomes
  the typing contract every later consumer reads `dossier.yaml` through.
- **D-25:** JSON fallback (spec §4.4) = **the same fixed filename**. The root marker stays
  `dossier.yaml` and only `dossier.yaml`, because every other component locates a dossier by
  that name (spec §3.2, fixed non-configurable names); if its content starts with `{` it is
  parsed with the `json` module instead of the YAML-subset parser. No `dossier.json` name is
  introduced. — Assumption A-05.

### Test harness (integration with the Phase 1 harness, never a replacement)

- **D-26:** One new file, `tests/test-lint.sh`. The existing `tests/run.sh` globs
  `tests/test-*.sh` and states that "adding a test file never requires editing this script" —
  verified by reading it; `run.sh` is not modified.
- **D-27:** `tests/lib.sh` is extended **additively only** — a `lint_py()` helper beside the
  existing `init_py()`, and lint-specific assertion helpers built on the existing
  `TESTS_PASSED`/`TESTS_FAILED`/`finish()` machinery. No existing helper changes signature or
  behaviour; the five Phase 1 test files must keep passing untouched.
- **D-28 (AMENDED 2026-09-17 by the mission manager — arbitration of the D-28 / D-31
  tension surfaced in `02-01-PLAN.md` § "Deviation from locked decision D-28"; the original
  wording is preserved below).** The two decisions are not jointly satisfiable in their literal
  form: git tracks no empty directory, so a committed scaffold silently loses
  `sources/transcripts/` and stops being byte-for-byte what `init.py` produces. **Retained:
  D-31's purpose wins — `tests/fixtures/lint/clean/` is NOT committed**, it is materialised at
  test time from a real `init.py` run, so ROADMAP criterion 1 keeps asserting something about
  the scaffolder instead of degrading into a tautology about a hand-maintained tree.
  `tests/fixtures/lint/fr/` stays committed exactly as D-28 says. D-28's own purpose — a
  readable reference — is carried instead by that French tree and by
  `tests/fixtures/make-lint-fixtures.sh`, whose header must document the clean layout it
  builds. This is a manager arbitration, not a human decision: Samuel can reverse it with the
  scoped edit already written in `02-01-PLAN.md` (no replan, no wave moves).
  *Original wording:* Fixtures live under `tests/fixtures/lint/`. Two are **committed static
  trees**, because they are the readable reference and criteria 1 and 3 assert on them:
  `tests/fixtures/lint/clean/` (a full layout with `.gitkeep` in every empty leaf → exit 0,
  zero findings) and `tests/fixtures/lint/fr/` (French content, `language: fr`, deliberately
  containing relative-date words and unsourced bullets → exit 0 with W1/W2 raised, and the
  English `Last updated:` label still found — ROADMAP criterion 3).
- **D-29:** The **error fixtures are generated at runtime** by
  `tests/fixtures/make-lint-fixtures.sh`, one throwaway tree per error class (E1…E9), each a
  copy of the clean base with exactly one violation injected, built under `mktemp -d`. Three
  reasons, in order of weight: (1) the E8 fixture needs a nested `.claude/` folder and this
  repository's `.gitignore` ignores `.claude/` at any depth, so it **cannot** be committed;
  (2) per-class isolation lets the test assert both "the expected ID fires" and "no other error
  ID fires", which catches false positives a single mega-fixture would hide; (3) the pattern
  already exists in the harness — `tests/fixtures/make-adopt-fixture.sh`. That script is left
  untouched. — **Reversibility:** costly — flipping to committed error trees means re-solving
  the `.claude/` ignore problem and rewriting the isolation assertions.
- **D-30:** Assertions are on **exit code + finding identifier** (D-05), not on golden output
  files. `tests/golden/` keeps its single Phase 1 artefact; no golden file is added for lint,
  because message prose will be tuned and a golden diff would fail for wording alone.
- **D-31:** The clean fixture is the regression guard for D-06: whatever `dossier-init`
  scaffolds must lint clean. The planner should build the clean fixture **by running
  `init.py`** into the fixture path (or by copying its exact output) rather than hand-writing
  it, so the two stay in sync.

### Claude's Discretion

- Internal structure of `lint.py` (function decomposition, order of checks, single-pass vs
  per-check walk), exact wording of each message after its `[ID]` token, the internal shape of
  the fixture generator script, and how the clean fixture is materialised from `init.py`.

### Assumptions (to be validated by Samuel)

Samuel was offline when this context was gathered. Each entry is a real product choice the
spec does not settle; the conservative option was taken.

- **A-01 (D-02): exit 2 when no `dossier.yaml` is found.** The spec only names exit 1
  (errors) and 0 (warnings only). Reusing 1 for "no dossier here" would make it impossible for
  `dossier-status` to tell "malformed dossier" from "not a dossier". Chosen: a third code, 2,
  for usage/configuration failures. Cheap to change: no consumer exists yet.
- **A-02 (D-07): "complete" status header = `Status:` + `To:` + `Written by:` (+ `Subject:`
  under `outbound/mails/`).** Spec §3.3 shows six fields but marks only `Subject:` and
  `Deadline:` as conditional. Requiring all six would make `Rules:` mandatory on every file;
  chosen the narrower set so the linter cannot become the reason a legitimate draft is
  rejected. `Rules:` unchecked in v1.
- **A-03 (D-10): slug charset `[a-z0-9]+(-[a-z0-9]+)*`.** The spec writes `YYYY-MM-DD_slug`
  without defining "slug". Chosen the lowercase-hyphen convention already used by
  `knowledge/decisions/YYYY-MM-DD_slug.md` in spec §3.2. This rejects `_` and uppercase inside
  a slug — the one assumption most likely to need loosening after real use.
- **A-04 (D-13): an absent living file is reported under E7.** The alternative is silence on a
  partially scaffolded dossier. Chosen the louder option: the layout is fixed and `init.py`
  creates all seven, so a missing one is a real defect.
- **A-05 (D-25): JSON fallback reuses the `dossier.yaml` filename.** Reading `{` as JSON keeps
  the fixed-name invariant that every other component depends on. A separate `dossier.json`
  would fork root discovery across the plugin.
- **A-06 (D-21): the exact v1 word lists.** The spec gives four examples ("tomorrow", "next
  week", "demain", "la semaine prochaine") and leaves the rest open. The lists above are a
  deliberately short, high-precision starting point — a warning that fires too often gets
  ignored, which is worse than a warning that misses a case.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Design spec (source of truth)

- `docs/superpowers/specs/2026-09-16-client-dossier-design.md` §3.2 — fixed names, the
  protocol keywords, the `dossier.yaml` shape and its ten keys, `.gitkeep` and the rule that
  the linter ignores it, nearest-`dossier.yaml` root discovery.
- `docs/superpowers/specs/2026-09-16-client-dossier-design.md` §3.3 — the status header and
  the three things the linter fails on (no block, `sent` without date/sender, non-absolute
  `Deadline:`).
- `docs/superpowers/specs/2026-09-16-client-dossier-design.md` §3.4 — the fact-line format and
  the "reconstructed" marker that W2 must tolerate.
- `docs/superpowers/specs/2026-09-16-client-dossier-design.md` §4.4 — the eight checks, the
  exit-code contract, and the sentence that limits language knowledge to the two warning word
  lists.
- `docs/superpowers/specs/2026-09-16-client-dossier-design.md` §6 — degraded modes (bare-skills
  install, missing external tools).
- `docs/superpowers/specs/2026-09-16-client-dossier-design.md` §7 — the mechanical-test
  contract: fixture dossiers, a bash runner, nothing beyond bash and python3.

### Planning

- `.planning/ROADMAP.md` §"Phase 2: Linter & Test Harness" — the four success criteria and the
  two carried-over Phase 1 debts (a) and (b).
- `.planning/REQUIREMENTS.md` — LINT-01 (the eight checks, exit codes, `.gitkeep` ignored),
  LINT-02 (fixtures), LINT-03 (bash runner).
- `.planning/PROJECT.md` §Open Decisions — the single remaining open point belongs to Phase 3
  (Stop hook), not here.
- `.planning/phases/01-scaffold-templates/01-CONTEXT.md` — D-05/D-06 (script carries the
  mechanics; `lint.py` stays at the repository root `scripts/` while `init.py` and the
  templates are bundled in the skill folder).

### Repository conventions

- `CLAUDE.md` (repository root) — `lint.py` at the root `scripts/`, stdlib only, exit 1/0,
  protocol keywords grepped in English with no per-language label table, fixed folder names,
  tests in bash + python3 only with a French-content fixture, plugin written in English.

### Phase 1 code the linter and the tests lean on

- `skills/dossier-init/scripts/init.py` — `FOLDERS`, `GITKEEP_LEAVES`, `TEMPLATE_MAP`,
  `render_dossier_yaml` (the exact bytes the parser must read back), and
  `_SAFE_PLAIN_SCALAR_RE` (debt (a)/(b), D-24).
- `skills/dossier-init/templates/en/`, `skills/dossier-init/templates/fr/` — what a clean
  dossier looks like; `README-outbound.md` is why D-06 exists; the seven templates carrying
  `Last updated:` are why D-13 names exactly those seven.
- `tests/run.sh`, `tests/lib.sh`, `tests/fixtures/make-adopt-fixture.sh` — the harness the new
  test file joins.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `tests/run.sh` — dispatcher globbing `test-*.sh`; a new `tests/test-lint.sh` is picked up
  with zero edits to the dispatcher.
- `tests/lib.sh` — `scratch_repo()`, `assert_file`, `assert_dir`, `assert_exec`,
  `assert_grep`, `assert_grep_e`, `assert_not_grep`, `assert_eq`, `finish()`, and the
  `init_py()` path-resolution idiom to copy for `lint_py()`.
- `tests/fixtures/make-adopt-fixture.sh` — the precedent for building a fixture tree at
  runtime (D-29).
- `skills/dossier-init/scripts/init.py` — a working, stdlib-only, 882-line script whose
  conventions (module-level constants for the fixed layout, `argparse`, docstrings explaining
  *why*) `lint.py` should mirror; it is also the producer whose output `lint.py` must parse.

### Established Patterns

- Fixed layout constants live at module level with a spec §-reference in the comment.
- Assertions are additive helpers on a shared pass/fail counter; a failed assertion records
  and continues (`set -u`, never `set -e`).
- Phase 1 scripts are executable and shebanged; `assert_exec` is already used on `init.py`.

### Integration Points

- `lint.py` reads what `render_dossier_yaml()` writes — the producer/consumer pair at the
  heart of D-23/D-24.
- The clean fixture is the contract between `init.py`'s output and the linter (D-31).
- `.gitignore` ignores `.claude/` at any depth — the direct cause of D-29.
- Future consumers (`dossier-status`, the `dossier-lint` command, `dossier-draft`) call
  `lint.py` as a subprocess and read its exit code; D-02's three-value exit contract is what
  they will be written against.

</code_context>

<specifics>
## Specific Ideas

- A freshly scaffolded dossier must lint **completely clean — zero errors and zero warnings**.
  That is the sharpest acceptance test of the whole phase and the reason D-06 (README
  exemption) and D-18 (commented example lines exempt) exist.
- Test assertions target stable identifiers (`[E4]`), never English sentences.

</specifics>

<deferred>
## Deferred Ideas

- `dossier-lint` slash command and `lint.py`'s invocation from `dossier-status` — Phase 6/7.
- The bare-skills fallback prose ("`scripts/` absent → state the rule the script would have
  checked") — belongs to the skills that call the linter, Phases 3/5/6.
- A `--fix` or `--format json` mode — not in the spec; revisit only if a consumer needs it.
- Extending `LANGUAGE_WORDS` beyond `en`/`fr` — driven by a real dossier in a third language.
- Git-awareness (linting only changed files) — out of scope; the linter reads the filesystem.

</deferred>

---

*Phase: 2-Linter & Test Harness*
*Context gathered: 2026-09-17*
