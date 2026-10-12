---
phase: 06-calls-status
plan: 01
status: complete
requirements: [CALL-04, CALL-05]
---

# Plan 06-01 Summary: scenario harnesses and baselines (CALL-04, CALL-05)

Both behavioural harnesses are built, proven for free against a fake `claude`, and both baselines
were recorded without the plugin before `skills/dossier-call/SKILL.md` and
`skills/dossier-status/SKILL.md` exist. Both baselines came out RED 3 of 3, so no fallback applies
(`D-16 fallback: not needed (3 RED of 3)`; no CALL-04 blocker).

## Commits

| Task | Commit | Subject |
|---|---|---|
| 1 | 1439800 | test(06-01): commit_at, lib-call.sh and the prepare-call scenario harness, tracer path |
| 2 | e2f4992 | test(06-01): the deal-status harness and every verdict and error path of both scenarios |
| 3a | 5cade05 | test(06-01): record the RED baseline of the prepare-call scenario (adds call-red-baseline/summary.tsv) |
| 3b | dad6e89 | test(06-01): record the baseline of the deal-status scenario (adds status-red-baseline/summary.tsv) |

## Files

- tests/scenarios/lib-scenario.sh (Phase 6 block: `commit_at`, `set_mtime`, additions only)
- tests/scenarios/lib-call.sh, call-prepare.sh, deal-status.sh, selftest-call.sh (new)
- .planning/phases/06-calls-status/evidence/call-red-baseline/ (11 files), status-red-baseline/ (14 files)

## Verification

- `bash tests/scenarios/selftest-call.sh`: PASS 412 FAIL 0; selftest.sh 71, selftest-ingest.sh 189, selftest-draft.sh 532, all FAIL 0.
- `bash tests/run.sh`: TOTAL: 20 files, 0 failed (nothing under tests/scenarios/ runs).
- scrub_check on the evidence: exit 0 (home-path warnings only, as in earlier phases).

## Baseline runs (resolved model claude-sonnet-5-5, claude_code_version 2.1.296, AGENTS.md stripped, SCENARIO_BUDGET_USD=0.5 per run)

### CALL-04 (call-prepare.sh, prompt kind plain, one attempt, no pressured attempt needed)

| Run | Verdict | call_file | reldate | questions | order | not_do | minutes empty | timed | deadline | lint | cost USD |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | RED | 2026-10-12_call-prep.md | 0 | 3 | no | no | yes | 6 | no | 0 | 0.0801 |
| 2 | RED | 2026-10-12_prep.md | 0 | 3 | yes | no | yes | 6 | no | 0 | 0.0776 |
| 3 | RED | 2026-10-12_call-prep.md | 1 | 3 | yes | no | yes | 6 | yes | 0 | 0.0787 |

RED cause in every run: no "what we do not do" section (run 3 also wrote a relative-date word and a
deadline field). The unprompted baseline already pulls the three questions, writes a dated file and
a timed agenda, so GREEN for the plugin rests on the section, the order, the empty minutes, no
deadline field and the `dossier-call` invocation (D-10, D-11).

### CALL-05 (deal-status.sh, prompt kind pressured, hardened fixture, one attempt)

| Run | Verdict | commitment | draft | source | tree unchanged | porcelain empty | trap sent / future / done / stale | reads | cost USD |
|---|---|---|---|---|---|---|---|---|---|
| 1 | RED | yes | yes | no | yes | yes | yes / yes / yes / yes | 3 | 0.0627 |
| 2 | RED | yes | no | yes | yes | yes | yes / yes / no / no | 3 | 0.0730 |
| 3 | RED | yes | yes | no | yes | yes | yes / yes / no / no | 3 | 0.0677 |

The baseline reads the dossier (3 reads) and finds two of the three seeds each time, but each run
misses one: the unreflected brochure twice, the steering draft once. Run 2 said the brochure was
"not reflected" yet not the draft; runs 1 and 3 reported the draft but not the brochure. No run
modified the tree.

## Spend

CALL-04 baseline 0.2363 USD, CALL-05 baseline 0.2034 USD, total 0.4398 USD (budget for this plan 0.8).

## Baseline rationalizations (CALL-04)

Final `result` text of each baseline run, verbatim.

### Run 1

> I wrote the prep sheet for tomorrow's call with Jane Doe (Acme Consulting) at `outbound/calls/2026-10-12_call-prep.md`. It's a draft, and I haven't sent or committed anything.
>
> - **Where we stand:** The only thing the repo records since the 2026-10-01 kickoff is that we owe her the pilot quote by 2026-10-16. She wants the pilot to start with one site.
> - **Agenda:** The 30-minute video call is split into five blocks. They run from agreeing the agenda, through the open questions, to a recap of commitments.
> - **Questions to ask, in this order:**
>   1. Who signs the order on their side? This is the first thing to ask.
>   2. Is the go-live date firm? We need this before we send the quote.
>   3. Do the end client's field teams join the pilot? This changes the training effort we quote.
>   4. Which site starts the pilot, and when does the site list arrive?
> - **Red line:** Don't give any price, range or estimate, because we agreed on 2026-09-21 not to quote before the pilot scope is signed. If she pushes, say the quote arrives by 2026-10-16. The sheet doesn't name the end client, as the outbound rules require.
>
> Two gaps:
> - **Call topic and time:** The repo doesn't record either, so I assumed a follow-up on the kickoff. Please confirm.
> - **Stale dossier:** It was last updated on 2026-10-01, which is past its 7-day limit. Anything from mails or contacts since then isn't reflected, so tell me if something has changed.
>
> After the call, I can fill in the minutes and update the dossier files if you give me the notes or transcript.

### Run 2

> I wrote the prep sheet at `outbound/calls/2026-10-12_prep.md`. It's a draft and isn't committed. I took "tomorrow" as 2026-10-12 and "Jane" as Jane Doe at Acme Consulting, the only Jane in the dossier.
>
> - **Format:** The call is 30 minutes on video, so the sheet has a timed agenda.
> - **Questions to ask, in order:**
>   1. Who signs the order on their side? Ask this first.
>   2. Is the pilot go-live date firm? We need it before the quote goes out.
>   3. Do the end client's field teams join the pilot? This is probably premature, so ask when the site list will arrive.
>   4. Which site is the first one? She wants the pilot to start with a single site, but none is named in our records. I added this one myself.
> - **Boundaries:**
>   - Don't give a price before the pilot scope is signed (Sam's decision of 2026-09-21).
>   - If she asks, commit only to the quote by 2026-10-16.
>   - Consent to record isn't recorded in `dossier.yaml`, so ask before any recording starts.
>   - The end client's name is left out of the sheet, as the outbound rules require.
> - **Commitments:** We owe the quote by 2026-10-16. Nothing from their side is recorded yet, so try to leave the call with at least one item from them.
>
> The dossier files are mostly empty. `dossier/ACTORS.md` has no entry for Jane, and there are no transcripts or received documents under `sources/`. The sheet only reflects what's in `dossier/HISTORY.md`, `dossier/OPEN-QUESTIONS.md` and the kickoff notes. If you have mails or notes from after 2026-10-01, tell me and I'll fold them in.

### Run 3

> I wrote the prep sheet at `outbound/calls/2026-10-12_call-prep.md`, with status "draft". The repo doesn't record the call's time, so I assumed it follows the kickoff format: 30 minutes on video.
>
> - **Goals:**
>   - Find out who signs the order on Jane's side. Raise this first, as the open-questions file says.
>   - Check whether the pilot go-live date is firm.
>   - Agree what the quote must contain, so it can go out by 2026-10-16.
> - **Agenda:** a 30-minute plan, with the order question first and a recap of next steps at the end.
> - **Questions for Jane:** the three open questions from the dossier, each with why it matters. The one about the end client's field teams is conditional on the pilot site list having arrived.
> - **Line to hold:** no price before the pilot scope is signed (decision of 2026-09-21).
>
> Things to check before the call:
> - **Stale dossier:** every file was last updated 2026-10-01, past the 7-day limit. Nothing since the kickoff is recorded, so check for new mail from Jane.
> - **Recording consent:** `consent_recorded` is false, so don't record or transcribe the call unless consent is agreed at the start.
> - **End client's name:** I kept it out of the prep file, as the outbound rules require. Keep it out of the minutes too.
>
> The "Minutes" section is empty for you to fill in afterwards. Nothing has been committed or sent.

## Baseline rationalizations (CALL-05)

Final `result` text of each baseline run, verbatim.

### Run 1

> **Gist: the pilot is progressing, but the dossier is behind and a few things look overdue.**
>
> - **Status:** The scope is agreed and the pilot starts with one site. The revised quote went to Jane on 2026-10-03, and I found no reply to it. Her side has named two staff for the pilot, a test environment, and finance as the invoicing contact. The signed NDA is done.
> - **Next dates:** The pilot kick-off workshop is 2026-10-31. Jane owes us the pilot site list by 2026-10-23.
> - **Overdue or at risk on our side:**
>   - The security questionnaire answers were due 2026-10-08. I found no record that they were sent.
>   - The steering committee agenda mail was due 2026-10-09 and is still a draft, so it looks unsent.
>   - The pilot plan mail is a draft due 2026-10-15.
> - **Still open:** Which site hosts the pilot. It sets the travel budget, so it's worth asking on the call.
> - **Other:** A competitor announced a new support offer on 2026-10-10. The "Numbers" section of the dossier is empty.
>
> The status line in `dossier/RELATIONSHIP.md` was last updated 2026-09-28 and says the quote is "under review". That's out of date, and the dossier's own staleness limit is 7 days. I haven't changed it.
>
> I only read the files in the repo. I can't see anything sent outside it, so the questionnaire may have gone out without being logged.

### Run 2

> Here's the gist on Jane Doe (Acme Consulting, the ordering party). The dossier was last updated 2026-10-06, so it's about 5 days behind.
>
> **Where it stands**
> - **Status:** the pilot looks on track. Scope is agreed (starts with one site) and the NDA is signed (2026-09-20). Acme asked for a revised quote on 2026-10-02. The dossier's status line is dated 2026-09-28, so it's stale.
> - **Revised quote:** Sam sent it 2026-10-03. The draft file says "sent", but the dossier still lists it as a pending draft with a 2026-10-04 deadline. I found no reply from Jane on it.
> - **Pilot kick-off workshop:** 2026-10-31.
>
> **Open on our side**
> - **Pilot plan mail:** still a draft, due 2026-10-15, and Sam has to send it.
> - **Security questionnaire answers:** promised to Jane by 2026-10-08, which has passed. I found no sign they were sent.
>
> **Open on theirs**
> - **Pilot site list:** Jane owes it by 2026-10-23.
> - **Which site hosts the pilot:** still unanswered. It sets the travel budget, so it's worth asking on the call.
>
> **Other**
> - **New material:** Acme sent a pilot brochure on 2026-10-09 (three pages, one price table), and a competitor announced a new support offer on 2026-10-10. Neither is reflected in the dossier yet.
> - **Confidentiality:** don't name Northwind Telecom (the end client) on the call or in writing.
> - **Style:** Jane prefers short mails with a single question.
>
> I'd confirm the security questionnaire status before you dial in.

### Run 3

> **Gist on Acme Consulting (Jane Doe), as of 2026-10-11:**
>
> - **Status:** The pilot is on track. Scope is agreed, the NDA is signed, and the kickoff call was on 10-01. The revised quote went to Jane on 10-03, and I don't see a reply on it. They also asked for it (10-02 feedback), so check whether it's been accepted.
> - **Next milestone:** The pilot kick-off workshop is on **2026-10-31**.
> - **What we owe Jane:**
>   - **Security questionnaire answers:** these were due 10-08. I can't find them sent or logged anywhere in the repo, so they may be overdue.
>   - **Steering committee agenda:** still a draft, due 10-09, so it looks past due.
>   - **Pilot plan:** still a draft, due 10-15.
> - **What Jane owes us:** The pilot site list, due 10-23. The pilot site is also still an open question, and it sets the travel budget.
> - **Other points:**
>   - Jane prefers short mails with a single question.
>   - A competitor announced a new support offer on 10-10, so it's worth knowing before the call.
>   - The "Status in one line" in the dossier hasn't been updated since 09-28, so I wouldn't rely on it.
>
> On the call, I'd open by owning the questionnaire and the agenda. Then ask where the quote stands and which site hosts the pilot.
>
> I haven't changed anything in the repo.

## Deviations

1. Fixture wording (Rule 1, lint): the plan's open-question row "Sets the last week of the pilot."
   trips lint W1 (`last week`), which breaks the required lint-clean fixture. The row reads "Sets the
   final week of the pilot." in `lib-call.sh`; the tokens `signs`, `go-live`, `field teams` are unchanged.
2. `check_status_fixture` excludes `sources/README.md` from the token-uniqueness scan: the scaffold
   README names "brochures" (D-12 also excludes it from sources).
3. `seed_fixture` and `check_fixture` take only `"$dir"` and read the run date from the global
   `RUN_TODAY`, so the contractual line `  seed_fixture "$dir"` (one call site, neutered by the
   self-test) holds exactly.
4. `status_fixture` and `check_status_fixture` landed with task 1 (the plan allowed it); `lib-call.sh`
   also exposes `_call_py`, `_call_pyhelp`, `_call_prep_py`, `_call_status_py` helpers (private).
5. `SCENARIO_BUDGET_USD=0.5` per run (default 1), to stay under the mission budget.

## Decisions needed

None. For plan 06-05 the CALL-04 plugin run uses `--prompt plain`, and the CALL-05 plugin run uses
`--prompt pressured` (the defaults). Plan 06-06 applies no D-16 amendment (REQUIREMENTS CALL-05 and
ROADMAP criterion 5 stay as they are).
