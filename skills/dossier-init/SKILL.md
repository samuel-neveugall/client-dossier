---
name: dossier-init
description: Use when someone wants to start or set up a dossier for a client, partner, prospect or recruiter in this repository, or when a repository already holds calls, mails and deliverables about an external party but has no dossier.yaml yet. Also use to complete a dossier scaffold that already exists in this repository — re-running only adds what is missing, it never overwrites a living file.
---

# dossier-init

Scaffolds a `client-dossier` layout into the current repository: `dossier.yaml`, the four
top-level folders (`sources/`, `dossier/`, `knowledge/`, `outbound/`) with their documented
subfolders, the seven living files under `dossier/`, the `knowledge/CONTEXT.md` and
`knowledge/DOCTRINE.md` stubs, one README per top-level folder, and a pointer to the protocol
in the repository's instructions file. On a repository that already holds the same material
under other names, it proposes — and, once confirmed, carries out — the `git mv` renames to
the fixed English layout.

The dossier root is the directory the user is already in: this skill never asks where to
scaffold, only what to scaffold with. Every input below is either already given (an argument,
or something stated plainly in the user's sentence) or collected through exactly one grouped
question — nothing here is asked twice. Re-running this skill on a dossier that already exists
completes only what is missing; it never overwrites a living file. Nothing this skill produces
is ever committed — the human reviews the working tree and commits it.

## What it produces

- `dossier.yaml` — the ten configuration keys, in this order: `version`, `language`,
  `counterparts`, `confidential_names`, `consent_recorded`, `consent_source`, `timestamps`,
  `date_format`, `status_header`, `staleness_days`.
- The four top-level folders, with a `.gitkeep` in every leaf folder the scaffold leaves
  empty, so an empty folder still survives a clone.
- The seven living files under `dossier/`, each opening with a `Last updated:` line and its
  "Updated when" rule.
- `knowledge/CONTEXT.md`, `knowledge/DOCTRINE.md`, and one README under each of `dossier/`,
  `sources/` and `outbound/`.
- A protocol-pointer section in `AGENTS.md` (always) and in `CLAUDE.md` (only when that file
  already exists) — see step 6.
- On an existing repository: the `git mv` renames from step 4, executed only after the human
  confirms them.

## Step 1 — Infer the language

Take the language of the conversation as the first guess. If the repository already has a
`CLAUDE.md` or an `AGENTS.md`, read its language too. Propose the result as the default answer
in the grouped question below — never scaffold silently in English when the conversation and
the repository both point elsewhere. The user confirms the proposed language or names another
one in their answer.

## Step 2 — Ask one grouped question, only for what is missing

Anything already given — stated plainly in the user's sentence or an argument they passed
(a counterpart's name, their role, a contact, the language, a confidential name to add) — is
used as is and never asked again. When nothing at all is specified ("set up a dossier for this
client"), ask exactly one grouped question: who the counterpart(s) are, with their role, and
which language to use (with the language inferred in step 1 proposed as the default).
Everything else — the confidential-name list, the date and timestamp formats, whether a status
header is required, `staleness_days` — is derived in step 3 or takes the spec's default; never
hand the user a scaffold that is only placeholders.

## Step 3 — Derive the confidential names and show them

Build `confidential_names` from the counterpart names collected in step 2, plus their short
forms — an organisation given as "Acme Consulting" also answers to "Acme". Show the resulting
list to the user and let them add or remove entries before anything is written; this is the
list a linter will one day refuse to let leak into `outbound/`.

## Step 4 — Propose adoption renames, confirm, then execute

Run:

```
${CLAUDE_SKILL_DIR}/scripts/init.py --target <dossier root> --propose-renames
```

against the repository the user is in. Show the proposal exactly as it is printed:

- `rename:` lines are an ordered script — each one is expressed against the state the
  repository would be in after every rename printed before it, so applying them top to bottom
  is always correct.
- `untracked:` lines mean git does not track that path — moving it with plain `mv` would lose
  its history; ask about each one separately before touching it.
- `unsafe:` lines are never renamed, no matter what the user says.
- `candidate:` lines are guesses — a folder that looks like a dossier under an unlisted name —
  and are never renamed without the user confirming that specific one.
- `ignored:` lines are folders with no dossier role, left alone on purpose.

Ask for one explicit confirmation before renaming anything. Without it, rename nothing and
move on to step 5 as if step 4 had found nothing to do. With it, apply every `rename:` line top
to bottom, one at a time:

```
git mv -- <old> <new>
```

using the two paths exactly as the proposal printed them — they are already shell-quoted, so
never re-quote them or reassemble the command from parts. For each `untracked:` line, ask
separately, and use plain `mv` only if the user accepts that history will not be preserved.
Whatever was or was not renamed, report it and never commit any of it: the review and the
commit are always the human's own next step.

## Step 5 — Choose the template variant

Two languages ship a hand-maintained template set: `en` and `fr`. When the confirmed language
is one of them, nothing further is needed. For any other language, pass `--template-variant en`
explicitly and translate the result yourself once the bundled script has written it: the
titles, the headings, the "Updated when" comments and the example lines move into the target
language, but every path and every protocol keyword (the `Last updated:` label, the
status-header field names and values) stay exactly as the script wrote them.

## Step 6 — Run the script, or do its job by hand

Run the bundled script with every value collected above spelled out as its own flag, so a
reader can reproduce the exact call:

```
${CLAUDE_SKILL_DIR}/scripts/init.py \
  --target <dossier root> \
  --language <code> \
  --template-variant <code, only if step 5 forced one> \
  --counterpart '<Name>|<role>|<contact>;<contact>' \
  --confidential-name '<name>' \
  --consent-recorded <true|false> \
  --consent-source '<text>' \
  --staleness-days <n>
```

(repeat `--counterpart` once per counterpart and `--confidential-name` once per name collected
in step 3).

### If the bundled script is not available

A bare-skills install, or a harness that cannot run Python, will not have it. Say so plainly —
the bundled script is not available here, so this is doing its job by hand — and then perform
the identical procedure, stated completely enough to reproduce it without the script:

- Create the four top-level folders — `sources/` (with `received/` and `transcripts/`, and
  `raw/` inside `transcripts/`), `dossier/`, `knowledge/` (with `decisions/` and `watch/`), and
  `outbound/` (with `deliverables/`, `mails/` and `calls/`) — for any of them that does not
  already exist.
- Write an empty `.gitkeep` file into each of these seven leaf folders, unconditionally, even
  one that looks empty already: `sources/received`, `sources/transcripts/raw`,
  `knowledge/decisions`, `knowledge/watch`, `outbound/deliverables`, `outbound/mails`,
  `outbound/calls`.
- Write `dossier.yaml` with its ten keys, in this exact order: `version` (`1`), `language`,
  `counterparts` (one block per counterpart, with `name`, and `role`/`contacts` only when
  given), `confidential_names`, `consent_recorded`, `consent_source`, `timestamps`,
  `date_format`, `status_header`, `staleness_days`.
- Create the twelve files below, each opened with today's date on its `Last updated:` line
  (the two knowledge stubs and the three READMEs carry no such line), from the chosen template
  variant, translating
  as step 5 says when the variant is not hand-maintained:
  - `dossier/ACTORS.md`, `dossier/HISTORY.md`, `dossier/LEARNINGS.md`, `dossier/TONE.md`,
    `dossier/CHANNELS.md`, `dossier/OPEN-QUESTIONS.md`, `dossier/RELATIONSHIP.md`
  - `knowledge/CONTEXT.md`, `knowledge/DOCTRINE.md`
  - `dossier/README.md`, `sources/README.md`, `outbound/README.md`
- Leave any path that already exists exactly as it is — never truncate, overwrite or merge
  into an existing file; report it as kept rather than created.
- Add the protocol-pointer section, delimited by its start/end marker comments, to
  `AGENTS.md` — creating the file if it is absent, appending the section if the file exists
  without it, and replacing the span in place if the markers are already there — and do the
  same to `CLAUDE.md`, but only when `CLAUDE.md` already exists; never create `CLAUDE.md`.

## Step 7 — Report

Say what was created, what was already there and kept untouched, what was renamed in step 4,
and what was left ignored — and say once more, plainly, that none of it was committed.

## Rules

- **Idempotent, never destructive.** Re-running this skill on an already-scaffolded repository
  completes only what is missing; an existing file is never truncated, overwritten or merged.
- **Confirm before renaming.** No `git mv` runs until the user has seen the step-4 proposal and
  given one explicit confirmation; without it, nothing is renamed.
- **Never commits.** Whatever this skill creates, renames or completes, the human reviews the
  working tree and commits it — this skill never runs `git commit`.
- **English artefacts, localised content.** The bundled script, this skill and every path they
  produce are English; only the dossier's own content — titles, headings, comments, example
  lines — follows the language steps 1 and 2 settle on.
