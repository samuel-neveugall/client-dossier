# STATE.md archive, 2026-10-12 (plan 07-09)

Resolved history moved out of STATE.md verbatim to keep it under 8 KB when the
pre-publication checklist (D-12) was added.

## Deferred Items rows (resolved)

| Category | Item | Status | Deferred At | Milestone |
|----------|------|--------|-------------|-----------|
| Debt (Phase 1 → Phase 2) | (a) YAML 1.1 reserved words: `init.py`'s `_SAFE_PLAIN_SCALAR_RE` lets `yes/no/on/off/true/false/null/y/n` through unquoted; `--language no` writes `language: no`, read back as boolean `False` by a strict YAML parser. Not a vulnerability (no key injection; `consent_recorded` unreachable) — a typing-fidelity gap. Fix when writing `lint.py`'s YAML-subset parser, aligning producer and consumer in one move. | Resolved — 02-03 (`bd2ecd2`): `_YAML_RESERVED_SCALARS` routes reserved spellings to `yaml_quote()`; pinned by `tests/test-init-empty.sh` d14. Round-trip through the lint parser still due in 02-06 | 2026-09-16 (Phase 1 review, round 3) | v1 |
| Debt (Phase 1 → Phase 2) | (b) Regex anchoring: same regex's `$` also matches just before a trailing `\n` (vs. `\Z`/`re.fullmatch`); a value ending in a newline passes the allowlist and leaves a blank line. No key injection — cosmetic guard bypass. One-line fix, bundle with (a). | Resolved — 02-03 (`bd2ecd2`): `emit_scalar` uses `fullmatch`; pinned by `tests/test-init-empty.sh` d15 | 2026-09-16 (Phase 1 review, round 3) | v1 |
| Debt (Phase 2 review, iteration 3) | Three reproduced fail-open paths of the confidentiality gate (E5), each letting a confidential name under `outbound/` pass with exit 0; none introduced by the fix rounds: CR-01 `Outbound/` on a case-insensitive filesystem escapes every outbound check; CR-02 zero-width/BOM/soft-hyphen characters in a name survive `init.py` and defeat the text match; CR-03 HTML entities in an outbound `.html` hide names. Plus WR-01 (near-miss rule rejects legitimate extra keys like `consent_scope`), WR-02 (two untested lines), WR-03 (unreadable dir or `.git/` under `outbound/` skipped silently), WR-04 (name wrapped across `> ` quoted lines). Details: `02-REVIEW.md`. | Resolved — gap closure 2026-09-25 (02-07..02-09 + review-fix rounds, branch `feat/phase-02-gap-closure`); Samuel ordered the fix round in UAT item 4 | 2026-09-24 (Phase 2 review, iteration 3) | v1 |

## Blockers/Concerns (resolved)

- Phase 2 is merged into `main` (`6fbd08d`); its planning assumptions and the D-24/D-28
  arbitrations were validated at the 2026-10-10 sign-off.
- The Stop-hook question (spec §11 #3) is settled by `03-CONTEXT.md` D-01 (ships, block-once);
  the spec, `CLAUDE.md`, PROJECT.md, ROADMAP and REQUIREMENTS were amended in Phase 3 (plans 03-03 and 03-06).
- 03-02 baseline gate resolved: D-15 pressured prompt gave RED 3/3 without the plugin (evidence/red-baseline/); plugin variant GREEN 3/3 (evidence/green-plugin/). P-01/P-02 stay provisional awaiting Samuel.
