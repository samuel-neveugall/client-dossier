# Phase 3 — review of the `dossier` skill and doc amendments (revue-3c)

HEAD c1deb00, full regime, read-only reviewer (vf-reviewer, 2026-10-10); persisted by the mission manager.
Verdict: **gaps_found** — 0 blocker, 2 major, 5 minor. `git fsck` clean; `test-skill-dossier.sh` 89/0.

| ID | Sev. | Action | Ref | Finding |
|---|---|---|---|---|
| S-M1 | major | auto-fix | skills/dossier/SKILL.md:3 | Frontmatter is not valid YAML: unquoted `description` contains `recruiter: preparing` (`: `); `yaml.safe_load` fails. Claude Code tolerates it, strict Agent Skills harnesses will not. Fix: reword (no `: `), add a test assertion. Do not just quote (test strips `description: ` and expects "Use when"). |
| S-M2 | major | auto-fix | spec §6 line 424, §4.1; CLAUDE.md:83; REQUIREMENTS.md:92 (PROTO-08 wording) | "every skill except `dossier-init` stops" still stated, while the entry skill steps aside (D-05). Amend to "every task skill stops; the `dossier` entry skill says so in one line and steps aside". |
| S-m3 | minor | auto-fix | tests/test-skill-dossier.sh:78-137 | 6 of 11 mutations survive: never-list bullets "Send…" and "Modify anything in `sources/`" not asserted; `Last updated:` not asserted; §2.4 rows asserted by name only; a pointer to a nonexistent skill passes; near-tautological `has` lines. Fix: every `dossier-[a-z]+` named must exist as `skills/<name>/SKILL.md`; assert `Last updated:`, both never-list bullets, one read-first cell per row. |
| S-m4 | minor | auto-fix | skills/dossier/SKILL.md:59-72 | §2.3 not fully carried: "a quote is checked in context before it is reused", "Last updated: date, after which event"; "exactly one parenthesised source" contradicts `Name (Organisation)` — reword "ends with one parenthesised source". |
| S-m5 | minor | no-op→auto-fix | skills/dossier/SKILL.md:82-85 | Only "the user asked me to fix it" was observed at the baseline; other rationalisations are anticipated — mark them as such. |
| S-m6 | minor | auto-fix | .planning/intel/constraints.md:167,248; intel/context.md:20; ROADMAP.md:196,340-342; 03-VALIDATION.md:121; CLAUDE.md:7-9 | Stale docs: `.sh` hook names and "Warning only" in intel snapshots; ROADMAP "3/6" counters and criterion 3 missing NotebookEdit/Bash guard; VALIDATION says P-01/P-02 awaiting Samuel; CLAUDE.md "State of the repository" mentions Phase 1 only. |
| S-m7 | minor | deferred to Phase 7 | evidence/*/ *.jsonl | Verdicts honest (RED 3/3: sha changed, typo edited; GREEN 3/3: sha identical, line in HISTORY.md after Skill→Read→Edit). No secret. Local data (`/Users/samuel`, session ids, thinking blocks) to scrub before the repository is made public (Phase 7 gate). Scope note: plugin + AGENTS.md present is not measured — added to the UAT. |
