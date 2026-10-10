# Phase 3: Protocol Skill & Hooks - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-10-10
**Phase:** 03-protocol-skill-hooks
**Areas discussed:** Stop hook in v1, Guard on sources/, Skill triggering and form, RED/GREEN scenario method

---

## Stop hook in v1

| Option | Description | Selected |
|--------|-------------|----------|
| Block once | Agent gets the reason and resumes once; second stop passes (stop_hook_active). Amends spec "never blocks" | ✓ |
| Warn the human only | Spec as written; the agent never sees the message | |
| Not in v1 | SessionStart + sources guard only | |

| Option | Description | Selected |
|--------|-------------|----------|
| git status, as the spec | Uncommitted changes under outbound/ or sources/, none under dossier/; stateless | ✓ |
| This session's changes | SessionStart baseline compared at Stop; more state | |

**User's choice:** Block once, triggered by git status.
**Notes:** Prompted by the fact that a non-blocking Stop hook only reaches the human in Claude Code.

---

## Guard on sources/

| Option | Description | Selected |
|--------|-------------|----------|
| Deny everything, new files included | Ingest files sources by script, never by Write | ✓ |
| Existing files only | Write may create a new file under sources/ | |

| Option | Description | Selected |
|--------|-------------|----------|
| Heuristic Bash guard | Deny sed -i, rm, mv, >, tee on existing files under sources/ | ✓ |
| Prose only | Spec as written | |

**User's choice:** Deny all Write/Edit/MultiEdit under sources/; add a heuristic Bash guard.

---

## Skill triggering and form

| Option | Description | Selected |
|--------|-------------|----------|
| Step aside, suggest init | Broad trigger; outside a dossier, one line + dossier-init suggestion, task continues | ✓ |
| Narrow trigger | Only in a repository with dossier.yaml | |

| Option | Description | Selected |
|--------|-------------|----------|
| One compact SKILL.md | Every rule in one file | ✓ |
| SKILL.md + references | Formats in references/ read on demand | |

| Option | Description | Selected |
|--------|-------------|----------|
| Existing skills only | Each later phase adds its pointer | ✓ |
| All five now | PROTO-02 as written | |

---

## RED/GREEN scenario method

| Option | Description | Selected |
|--------|-------------|----------|
| Rerunnable script, outside run.sh | tests/scenarios/, headless claude -p with and without --plugin-dir | ✓ |
| One-off recording | Manual sessions, transcripts in the phase folder | |

| Option | Description | Selected |
|--------|-------------|----------|
| Source intact + correction filed | Hash unchanged and a dated, sourced correction line in dossier/ | ✓ |
| Source intact + refusal explained | ROADMAP wording | |

| Option | Description | Selected |
|--------|-------------|----------|
| 3 runs, GREEN 3/3 | RED at least once without the plugin | ✓ |
| 1 run each | Cheapest | |

---

## Claude's Discretion

- Hook language (Python 3.8 stdlib instead of the spec's .sh), hook file layout and wording,
  the Bash heuristic list, hook mechanical tests in tests/run.sh.
- Codex mirror of the hooks deferred to Phase 7.

## Deferred Ideas

- Codex hook mirror — Phase 7.
- Pointers to the four task skills — Phases 4-6.
