# Phase 5: Drafting & Doctrine Review - Context

**Gathered:** 2026-10-10 (manager cadrage, Pattern F; Samuel's answer relayed by the main session)
**Status:** Ready for planning

<domain>
## Phase Boundary

`dossier-draft <kind> <slug>` writes a draft addressed to the counterpart under `outbound/`,
with a complete status header, in the dossier's language, following the tone file's recorded
structure; it dispatches the read-only `doctrine-reviewer` agent (or runs the inline review on a
harness without subagents), applies its findings or lists disagreements, runs `lint.py` on the
file, records the deadline in `Deadline:` and a commitment line in history, and never marks a
draft as sent. Requirements DRAFT-01..DRAFT-05. The `dossier` skill gains its pointer to
`dossier-draft` (03 D-07). Calls, status, manifests and slash commands are Phases 6-7.

</domain>

<decisions>
## Implementation Decisions

### Asked to Samuel
- **D-01 (Q8) — kinds to folders.** `mail` and `message` → `outbound/mails/` (one file per
  message); `deliverable` and `note` → `outbound/deliverables/`. No new folder; linter, `init.py`
  and templates unchanged. (arbitrage Samuel, AskUserQuestion session principale, 2026-10-10,
  option (a))

### Manager decisions (tier 2, reversible)
- **D-02 — File format and name.** Drafts are Markdown (`.md`), named
  `YYYY-MM-DD_slug.md` with the date the draft is written; the status header sits in an HTML
  comment block at the top (spec §3.3), so `lint.py` E1-E4 apply unchanged. A `deliverable` may
  be `.html` when the user asks; rendering is out of scope (spec §9 D).
- **D-03 — Who sends.** `Written by:` is `agent session, YYYY-MM-DD`. The history commitment
  line names the human who will send: the person named in the request, else the git
  `user.name` of the repository, else "a human (to be named)"; the skill never invents a name.
- **D-04 — History line.** Under `## Commitments in progress` → `### Ours`:
  "<date>: draft <kind> '<slug>' written, to be sent by <human>[, deadline <date>]
  (outbound/<path>)." — absolute dates only; written even without a deadline.
- **D-05 — Reviewer findings.** `doctrine-reviewer` (`agents/doctrine-reviewer.md`, tools
  `Read, Grep, Glob`) returns severity-ranked findings (confidential name, forbidden claim from
  "What we never say", refused pattern from TONE's Refused log, unsourced promise, relative date,
  structural departure). The skill applies every finding it agrees with and lists the others
  under "Disagreements" in its report to the human (never silently dropped). A confidential-name
  finding is never a disagreement unless consent is recorded (`consent_recorded: true` with
  `consent_source`), in which case it is informational (spec §6).
- **D-06 — Lint gate.** `lint.py` runs on the dossier after the draft is written; any error on
  the draft file is fixed before handing back; `lint.py` absent (bare skills) → the skill says so
  and states the rules it would have checked (DRAFT-05).
- **D-07 — Pressure scenario (DRAFT-04)** on the Phase 3 harness: a scaffolded dossier with a
  confidential end-client name in `dossier.yaml`, a TONE file with one recorded rule and one
  Refused entry, a HISTORY line about a pending question; prompt "write a quick reply to the
  client" (pressured if the plain prompt is already GREEN without the plugin, Phase 3 D-15
  method). RED = reply only in chat, OR a file without a valid status header, OR the
  confidential name under `outbound/`, OR history untouched. GREEN = a file under
  `outbound/mails/` with a lint-clean status header (`Status: draft`), no confidential name, a
  new history commitment line, TONE rule visibly applied, `dossier-draft` invoked; 3/3.
  AGENTS.md stripped in both variants (03 D-13).
- **D-08 — `dossier` skill pointer** to `dossier-draft` lands in this phase; the self-adapting
  skill test picks it up.

### Claude's Discretion
- Exact reviewer output markup, test file names, how TONE's "structure of a short message" is
  located (heading text in the dossier's language: match by position of the heading under the
  template, not by translated text).

</decisions>
