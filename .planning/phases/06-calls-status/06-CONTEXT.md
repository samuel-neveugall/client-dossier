# Phase 6: Calls & Status - Context

**Gathered:** 2026-10-10 (manager cadrage, Pattern F; Samuel's answer relayed by the main session)
**Status:** Ready for planning

<domain>
## Phase Boundary

`dossier-call prepare <date> <slug>` writes a call file under `outbound/calls/` (context,
objectives, timed agenda, "what we do not do", open questions ordered by when to ask, empty
minutes); `dossier-call debrief <transcript>` ingests the transcript through `dossier-ingest`,
fills the minutes, moves answered questions with timestamps, adds owned and dated commitments to
history, and updates `RELATIONSHIP.md` at a milestone. `dossier-status` prints, read-only, the
one-line status, due commitments, unreflected sources, overdue drafts (`Deadline:`), stale living
files (`staleness_days`) and lint findings. Requirements CALL-01..CALL-05. The `dossier` skill
gains its pointers to `dossier-call` and `dossier-status`, which completes PROTO-02 (03 D-07);
the Stop hook's `dossier-status` sentence appears on its own (03 D-14). Manifests, commands,
README and eval are Phase 7.

</domain>

<decisions>
## Implementation Decisions

### Asked to Samuel
- **D-01 (Q9) — one call file in `outbound/calls/`.** Confidential parties are named by role
  ("the end client"); sensitive strategy is referred to `knowledge/` or `dossier/` rather than
  written in the call file. (arbitrage Samuel, AskUserQuestion session principale, 2026-10-10,
  option (a))

### Manager decisions (tier 2, reversible)
- **D-02 — `dossier-status` mechanics are a script.** A private, read-only
  `skills/dossier-status/scripts/status.py` (Python 3.8+ stdlib) computes every item; the skill
  carries judgement only (presenting it, suggesting the next step). It calls `scripts/lint.py`
  when present (plugin root found through `${CLAUDE_PLUGIN_ROOT}` or the skill dir's parent);
  absent → says so and states the rules (bare skills). It never writes anything.
- **D-03 — Due commitments:** lines under the history file's "Commitments in progress" section
  (located by position under the template headings, language-independent) carrying an absolute
  date; reported as overdue (date < today) or due soon (within the next 7 days), each with its
  date and owner text.
- **D-04 — Unreflected source:** a file under `sources/` whose filing time (first git commit
  time; uncommitted files count as new; mtime outside git) is later than the most recent
  `Last updated:` date across the living files.
- **D-05 — Overdue draft:** an outbound file whose status is `draft` (or `reviewed by`) and
  whose `Deadline:` is before today. Stale file: `Last updated:` older than `staleness_days`.
- **D-06 — Call file:** `outbound/calls/YYYY-MM-DD_slug.md`, the date being the call date (a
  relative date such as "tomorrow" is converted to an absolute date before writing), with the
  status header (`Status: draft`, `To:` the counterpart by role), sections in the dossier's
  language; open questions pulled from the open-questions file's "still open" table, ordered by
  "When to ask".
- **D-07 — Debrief:** runs `dossier-ingest` on the transcript first, then fills the minutes of
  the matching call file (same date, else the most recent prep), else creates one; moves answered
  questions to the "Answered" table with the transcript locator; milestone judgement (scope,
  price, signature, deadline change, a decision-maker joins) decides the `RELATIONSHIP.md` update
  and the skill says which signal it used.
- **D-08 — Scenarios CALL-04 / CALL-05** on the Phase 3 harness (AGENTS.md stripped in both
  variants; pressured prompt only if the plain one is already GREEN without the plugin):
  "prepare tomorrow's call" — RED = a relative date written, or open questions not pulled, or no
  "what we do not do" section; GREEN = a call file with an absolute date, the seeded open
  questions in "when to ask" order, the section present, lint-clean, `dossier-call` invoked, 3/3.
  "where are we with this deal" — fixture seeds an overdue commitment, an overdue draft and an
  unreflected source; RED = any of the three missed; GREEN = all three reported, no file
  modified, `dossier-status` invoked, 3/3.
- **D-09 — Pointers** to `dossier-call` and `dossier-status` land in the `dossier` skill; the
  self-adapting skill test then verifies PROTO-02 in full; PROTO-08 (task skills stop outside a
  dossier) is verified for all task skills at this phase.

### Claude's Discretion
- Output format of `status.py` (plain text sections, plus `--json` for tests), file names of
  tests, agenda timing granularity.

</decisions>
