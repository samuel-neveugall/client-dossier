# Milestones

## v1 client-dossier v1 (Shipped: 2026-10-13)

**Delivered:** A coding-agent plugin that turns a git repository into the memory of a relationship
with an external party: six skills, two read-only agents, three hooks, `scripts/lint.py`, en/fr
templates, Claude Code and Codex manifests, released locally as `v1.0.0`.

**Phases completed:** 7 phases, 46 plans, 62 tasks
**Requirements:** 42/42 (SCAF, LINT, PROTO, INGEST, DRAFT, CALL, DIST)
**Audit:** `milestones/v1-MILESTONE-AUDIT.md`, status `tech_debt`, no blocker
**Closeout type:** override_closeout
**Timeline:** 2026-09-16 → 2026-10-12 (27 days), 400 commits
**Git range:** `0516394` (design spec) → `8e220b6` (merge of chore/v1-cleanup)
**Size:** 592 files changed, +81,452 lines; about 6,800 lines of shipped Python (linter, skill
scripts, hooks), 53 bash test files (31 in `tests/run.sh`, 0 failed at close)

**Key accomplishments:**
- Phase 1: `dossier-init` scaffolds the fixed English layout, `dossier.yaml` and the seven living
  files from en/fr templates, writes the protocol pointer into `AGENTS.md`, and proposes `git mv`
  renames for an existing repository.
- Phase 2: `scripts/lint.py` (Python 3.8+ stdlib, YAML-subset parser) enforces E1-E9 and W1-W2, with
  a hardened confidential-name check (E5) against markup, HTML entities, format characters and
  homoglyphs; proven by runtime-generated fixtures and a bash runner.
- Phase 3: the `dossier` entry skill and three hooks (PreToolUse guard on `sources/`, SessionStart
  reminder, block-once Stop check); the "fix the typo in the transcript" scenario went RED 3/3
  without the plugin and GREEN 3/3 with it.
- Phase 4: `dossier-ingest` files sources by script (hash dedup, SSRF-guarded URL download,
  `extract-text.sh`) and applies dated, sourced facts proposed by the read-only `fact-extractor`.
- Phase 5: `dossier-draft` writes status-headed outbound drafts checked by the read-only
  `doctrine-reviewer` and gated by the linter; GREEN 3/3 plus a French deadline run.
- Phase 6: `dossier-call` (prepare and debrief) and `dossier-status` (backed by `status.py`: due
  commitments, unreflected sources, overdue drafts, stale files), both GREEN on their scenarios.
- Phase 7: both manifests and marketplaces, the `dossier-lint` command (D-18), README, MIT LICENSE,
  CHANGELOG, `scripts/release.sh`, four install paths proven in isolation, routing eval 1.0 on 8/8.

**Known verification overrides:** 3 newly acknowledged, 0 carried forward from a prior close (see
STATE.md Deferred Items)
- `01-VERIFICATION.md` (human_needed): human verification done by Samuel on 2026-09-17.
- `03-VERIFICATION.iter1.md` (gaps_found) and `04-VERIFICATION.iter1.md` (human_needed): history
  snapshots, superseded by the passed `03-VERIFICATION.md` and `04-VERIFICATION.md`.
- At close, `init.manager` projected phases 1-4, 6 and 7 as `stale` (a covered file changed after
  each VERIFICATION report, during later fix and cleanup rounds); every report reads `passed`
  except Phase 1's, and the milestone audit covers all seven phases. Closed as an override by
  Samuel's decision (2026-10-12).

**Tech debt carried (accepted):** see the audit frontmatter. Bash guard class D-04 (D-17), E5
abbreviations and acronyms (05 D-09), Phase 2 OBS-01 and the double-typo residual, Codex hooks
never run live (W2), E5 gate unavailable outside Claude Code (W1), Nyquist VALIDATION files left
in draft.

---
