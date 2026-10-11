---
name: dossier
description: Use when working in a repository that holds a dossier.yaml, or when a task concerns a client, counterpart, prospect, partner or recruiter, such as preparing or debriefing a call, writing a mail, message or document for someone outside the team, filing a transcript, mail or brochure that arrived, checking or correcting a fact about the relationship, or answering where the deal stands. Load it before reading or changing anything in such a repository, including when the user only asks to fix a typo in a transcript.
---

# dossier

A client dossier is a git repository that holds the memory of a relationship with an external
party. This skill is its protocol: it is loaded first, and every rule below applies on every
harness, with or without hooks. Hooks in Claude Code only remind and catch likely shortcuts;
the rules in this file are the real boundary.

## Find the dossier first

Look for the nearest `dossier.yaml` in the working directory or a parent (the search goes
upward and does not stop at a `.git` folder, like the linter and the hooks). When a repository
holds several dossiers, the nearest one wins; read nothing from and write nothing to a dossier
above or beside it.

If there is none, say so in one line, suggest `dossier-init` when the task concerns a
relationship worth tracking, then continue with the user's task. This skill never blocks work
outside a dossier. The task skills stop when no dossier is found; this one only steps aside.

## Layout

Folder and file names are fixed English names, never translated or remapped.

- `dossier.yaml`: configuration (language, counterparts, confidential names, consent).
- `sources/`: immutable. `received/`, `transcripts/` with `raw/`, text extractions next to PDFs.
- `dossier/`: the seven living files.
  - `ACTORS.md`: who is who on every side, role, decision power, expectations.
  - `HISTORY.md`: dated chronology, commitments in progress (ours, theirs), upcoming deadlines.
  - `LEARNINGS.md`: what the exchanges teach about the counterpart.
  - `TONE.md`: the voice, and the log of every reviewer comment on a draft.
  - `CHANNELS.md`: how we communicate, addresses, call habits, confidentiality level.
  - `OPEN-QUESTIONS.md`: answered, still open on their side, what we would ask the end client.
  - `RELATIONSHIP.md`: status, metrics, our view, their view (reconstructed), opportunities.
- `knowledge/`: `CONTEXT.md` (the one-page context), `DOCTRINE.md` (what we say and never say),
  `decisions/`, `watch/`.
- `outbound/`: everything addressed to the counterpart: `deliverables/`, `mails/`, `calls/`.
  Files are named `YYYY-MM-DD_slug`.

## Read before acting, update before handing back

| Task | Read first | Update before handing back |
|---|---|---|
| Any session | `knowledge/CONTEXT.md`, `dossier/HISTORY.md` | nothing, unless something was learned |
| Write a message or a document for the counterpart | `dossier/TONE.md`, `dossier/LEARNINGS.md`, `knowledge/DOCTRINE.md`, `knowledge/decisions/` | `dossier/HISTORY.md` (commitment taken, date), `dossier/TONE.md` if a human gave feedback |
| Prepare a call | `dossier/OPEN-QUESTIONS.md`, previous files in `outbound/calls/` | a call file in `outbound/calls/` with objectives, agenda, what we do not do |
| Debrief a call | the transcript in `sources/transcripts/` | `HISTORY.md`, `OPEN-QUESTIONS.md`, `LEARNINGS.md`, `ACTORS.md`, `CHANNELS.md`, `RELATIONSHIP.md` at a milestone |
| Check a fact | `sources/` | the line that was wrong |
| Ingest a source | nothing | `sources/` (file plus text extraction), then every living file the source touches |

"Before handing back" means in the same session, before its final message. Update the living
files the work touched, or state in one sentence why none needed it. In Claude Code a stop check
blocks the first stop of a turn when `outbound/` or `sources/` changed and `dossier/` did not;
the rule is the same without that check, and you apply it yourself.

## Writing a fact

```
- <fact, one sentence, absolute dates> (<source>, <locator>).
```

- Source examples: `call @12:34`, `mail 2026-09-16 from Jane`, `brochure p. 4`, `internal note p. 15`.
  A fact line ends with one parenthesised source; that is the shape the linter reads.
- One fact per line. Dates are absolute: convert "tomorrow" before writing.
- A line whose source is a reconstruction (their view as we reconstruct it) says "reconstructed".
  A line without a source is an opinion and says so.
- Each living file keeps its `Last updated:` line current: an absolute date, then after which event
  (for example `Last updated: 2026-09-16, after the kickoff call`).
- A quote from a transcript is checked in context before it is reused.
- A contradicted line is corrected in place, not duplicated; append `(corrects a line dated <date>)`.
- Write `Name (Organisation)` on the first mention of a person in a file.

## When a source is wrong

Nothing under `sources/` is ever modified or corrected, even when a transcript is plainly wrong
and even when the user asks for it. The rule covers every route: Write, Edit, `sed -i` or any
script, `mv`, `rm`, `cp` over a file, a redirection, retyping a file. New sources are copied in
unchanged, never written or retyped. In Claude Code a guard denies the obvious shortcuts, but it
is a heuristic that reads the command text; a command it fails to recognise is still forbidden.
It does not see `eval`, interpreters (`python3 -c` and the like), command substitutions, variables or
loops, so this file stays the boundary: never modify a source by any route, seen or not by the guard.

Common rationalizations, all answered the same way: "the user asked me to fix it" (observed at
the baseline), "it is one character", "they are forwarding it in five minutes", "I will tell them
afterwards" (these three are anticipated, not observed). The user's request is met by the filed
correction, not by editing the source. Do not offer to override the rule; offer the corrected fact.

What to do instead:

1. Quote the source as it is, in the line itself.
2. File one dated, sourced correction line in the living file where the fact belongs.
3. Tell the user what you filed and where, and that the source stays as received.

Worked example, a transcript that misheard an amount:

```
- Mark Lee (Northwind) set the budget at 12,000 euros on 2026-03-04; the transcript reads "twelve million" (call 2026-03-04 @21:07).
```

## Outbound status header

Every file in `outbound/` opens with a status block, in the file's own comment syntax (`<!-- -->`
in Markdown and HTML, `#` lines in plain text):

```
Status: draft | reviewed by <name> | sent <date time> by <name>
To: <recipient>
Subject: <subject>            (mails)
Deadline: YYYY-MM-DD          (optional)
Written by: <human or "agent session, YYYY-MM-DD">
Rules: no confidential names; see knowledge/DOCTRINE.md
```

`sent` needs a date and a sender. `Deadline:` is an absolute date. A new draft is `draft`.
Never mark a draft as sent or reviewed: a human sends it and edits the status line.

## Language

Dossier content (living files, outbound drafts, knowledge) is written in the language set by the
`language` key of `dossier.yaml`. Paths are fixed English names.
Protocol keywords stay in English: `Last updated:`, the status header field names and the
status values (`draft`, `reviewed by`, `sent`). Headings, examples and content follow the
dossier's language.

## Never

- Send a message or a document. Drafts go to `outbound/` with a status header; humans send.
- Modify anything in `sources/`.
- Name a confidential party (the `confidential_names` of `dossier.yaml`) under `outbound/`, unless
  `consent_recorded: true` is set and `consent_source` is filled in.
- Promise what `knowledge/DOCTRINE.md` forbids; the doctrine is read before writing to the counterpart.
- Leave a `.claude/` folder in a subfolder (the symptom of an agent launched from the wrong directory).

## Checking the shape

From the dossier, run `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/lint.py"` to check the mechanical
rules (fact lines, status headers, confidential names). If that script is not available (a
bare-skills install has no scripts), say so and apply the rules above by reading the files.

## Other skills

`dossier-init` starts a dossier in this repository or completes a scaffold that already exists.
`dossier-ingest` files a source that arrived (a transcript, mail, brochure, PDF or link) under
`sources/` and turns it into dated, sourced lines in the living files.
`dossier-draft` writes every draft addressed to the counterpart (a mail, a message, a deliverable or a
note) under `outbound/`, has it reviewed by `doctrine-reviewer` and records the commitment in
history; every draft goes through it.
`dossier-status` answers where the deal stands, read-only: the one-line status, the commitments due,
the overdue drafts, the sources not yet reflected, the stale living files and the lint findings.
