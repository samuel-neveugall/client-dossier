# Outbound

Every file in this folder opens with a status header, verbatim:

```
Status: draft | reviewed by <name> | sent <date time> by <name>
To: <recipient>
Subject: <subject>            (mails)
Deadline: YYYY-MM-DD          (optional: when the draft has to be sent)
Written by: <human or "agent session, YYYY-MM-DD">
Rules: no confidential names; see knowledge/DOCTRINE.md
```

Files are named `YYYY-MM-DD_slug` (plus their extension).

- `deliverables/` — a rendered file keeps its source file beside it, same stem.
- `mails/` — one file per message.
- `calls/` — preparation, then minutes.

Two standing rules: no confidential name ever appears in a file under this folder, and nothing
leaves this repository without a human sending it.
