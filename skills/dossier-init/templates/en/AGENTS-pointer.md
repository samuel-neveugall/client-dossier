This repository is a **client dossier**: a git repository that holds the memory of a
relationship with an external party, managed by the `client-dossier` coding-agent plugin.

- `sources/` — immutable. Never edited once it lands; corrections go in the living files.
- `dossier/` — the seven living files: what is currently true about this relationship, each
  fact on its own dated, sourced line.
- `knowledge/` — the internal context and doctrine this relationship is checked against.
- `outbound/` — everything addressed to the counterpart. Every file opens with a status
  header, and a human always sends it — an agent never sends a draft from here.

Read before acting: `dossier/` and `knowledge/CONTEXT.md`. Update before handing back:
whichever living files the work touched.

Every fact is one sentence, an absolute date, and a source in parentheses (a call timestamp,
a mail date and sender, a document page). A contradicted line gets corrected in place, not
duplicated.

Never: edit anything under `sources/`, send anything, or name a confidential party in
`outbound/`.

Configuration lives in `dossier.yaml`. The full protocol lives in the `dossier` skill of the
`client-dossier` plugin.
