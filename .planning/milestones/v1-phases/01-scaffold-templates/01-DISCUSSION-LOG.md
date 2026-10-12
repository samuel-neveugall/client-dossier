# Phase 1: Scaffold & Templates - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-16
**Phase:** 1-Scaffold & Templates
**Areas discussed:** Input collection, Script vs prose, Templates and origin repository, Adopting an existing repository

---

## Input collection

| Option | Description | Selected |
|--------|-------------|----------|
| Mix: arguments then questions | Use what is given, one grouped question for the rest | ✓ |
| Always interactive | Ask every time | |
| Arguments only | Stop and print usage without full arguments | |

| Option | Description | Selected |
|--------|-------------|----------|
| One minimal grouped question | Counterpart(s) + role, language; rest derived or defaults | ✓ |
| Immediate scaffold with placeholders | TODO values, no question | |

| Option | Description | Selected |
|--------|-------------|----------|
| Inferred then confirmed | Conversation / CLAUDE.md language proposed as default | ✓ |
| Always asked explicitly | No default | |
| English by default | | |

| Option | Description | Selected |
|--------|-------------|----------|
| Derived + short forms | Counterpart names plus short variants, editable list | ✓ |
| Derived as is | Full names only | |
| Asked separately | | |

**User's choice:** all recommended options.
**Notes:** none.

---

## Script vs prose

| Option | Description | Selected |
|--------|-------------|----------|
| Script + inline fallback | stdlib init.py for the deterministic part, skill keeps judgement | ✓ |
| All prose in the skill | | |
| All in the script | Interactive CLI | |

| Option | Description | Selected |
|--------|-------------|----------|
| en + fr variants shipped, skill translates the rest | Deterministic French output | ✓ |
| English only, skill always translates | Strict spec §4.5 | |

| Option | Description | Selected |
|--------|-------------|----------|
| Complete without overwriting | Idempotent, reports additions | ✓ |
| Refuse and stop | | |
| Ask file by file | | |

| Option | Description | Selected |
|--------|-------------|----------|
| Inside the skill folder | skills/dossier-init/{scripts,templates}/, survives bare-skills install | ✓ |
| Root scripts/ like lint.py | Matches spec §4 tree | |

**User's choice:** all recommended options.
**Notes:** the spec §4 architecture tree must be amended (templates move under the skill).

---

## Templates and origin repository

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, local | Path found by search: ~/Documents/dev/Project-POC-RELATION-CLIENT, confirmed by user | ✓ |
| No, spec §2 only | | |

| Option | Description | Selected |
|--------|-------------|----------|
| Skeleton faithful to the spec | Title, Last updated, comment, §2.2 sections, one example | ✓ |
| Rich and guided | Sub-sections, several examples, advice | |

| Option | Description | Selected |
|--------|-------------|----------|
| HTML comment | Invisible when rendered, ignored by the linter | ✓ |
| Visible line to delete | | |

| Option | Description | Selected |
|--------|-------------|----------|
| Guiding questions as comments | 2-3 per section in CONTEXT/DOCTRINE stubs | ✓ |
| Headings only | | |

**User's choice:** all recommended options; origin repository confirmed.
**Notes:** the origin repository's content is confidential — structure only.

---

## Adopting an existing repository

| Option | Description | Selected |
|--------|-------------|----------|
| Known names + content hints, then confirmation | FR/EN table + living-file hints, mapping confirmed | ✓ |
| Mapping asked from the user | | |
| Known names only | | |

| Option | Description | Selected |
|--------|-------------|----------|
| Execute after confirmation | Runs git mv, never commits | ✓ |
| Print commands only | Two passes | |

| Option | Description | Selected |
|--------|-------------|----------|
| AGENTS.md always + CLAUDE.md if present | Marker-delimited section, idempotent | ✓ |
| Existing file, else AGENTS.md | | |
| Both, always | | |

**User's choice:** all recommended options.
**Notes:** origin layout (client/, communication/, docs/, sources/, pipeline/) is the reference adoption case.

## Claude's Discretion

- Wording of the grouped question and of the final report.
- Internal structure of init.py; `.gitkeep` detection; marker comment syntax; language inference.

## Deferred Ideas

- Origin `pipeline/` (rendering) — out of v1 (spec §9 D).
- Extra `sources/` subfolders (`internes/`, `plaquette/`) — spec layout stands; revisit at Phase 4 if needed.
