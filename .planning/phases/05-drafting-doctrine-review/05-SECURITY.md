# Phase 5 — security audit (audit-5)

HEAD 34feaca; vf-auditer via gsd-security-auditor (SECURED, T-05-01..T-05-30 + T-05-SC closed at ASVS L1),
2026-10-11; persisted by the mission manager. Verdict: **gaps_found** — 0 blocker, 1 major, 7 minor.

Reproduced as caught by E5 (exit 1): case, diacritics (precomposed/NFD/stripped), full-width, invisible
characters (ZWSP, word joiner, VS16, tags), name in `To:`/`Subject:`, name split over 2-3 lines or in
`>` quotes or with a line-end hyphen between words, HTML entities, name in the file name, any outbound
subfolder, UTF-16/Latin-1/>5 MB/symlink files fail closed (E1). Consent: `true` without source → E6 and
E5 stays armed; only a filled source disarms E5; the skill never sets consent. No send path, `Status:
draft` only; reviewer tools `Read, Grep, Glob` confirmed at runtime; no secret in the evidence.

| ID | Sev. | Action | Ref | Finding |
|---|---|---|---|---|
| A5-F1 | major | fix (no debt) | skills/dossier-draft/SKILL.md:205,211-216; dossier-ingest/SKILL.md:233 | Unquoted `${CLAUDE_PLUGIN_ROOT}`: a path with a space makes `test -f` fail and the skill falls back to "Without the linter"; lint exit 2/3 not treated as "E5 did not run" (reproduced with a Latin-1 `dossier.yaml`: exit 2, leaking draft not flagged). Fix: quote; exit ∉ {0,1} or missing linter = gate not passed, manual check mandatory. |
| A5-F2 | minor | ask-user (Q13) | scripts/lint.py:1515,1582,1296 | E5 misses markup between words (`**Big** Telco`, `<b>Big</b> Telco`, `Big<wbr>Telco`, `[Big](u) [Telco](v)`, spans), apostrophes other than U+2019, mid-word hyphenated line break, `%20`/`+` in file names, double HTML encoding. |
| A5-F3 | minor | ask-user (Q13) | scripts/lint.py E5; doctrine-reviewer rule 3 | Homoglyphs (Cyrillic `с`) and abbreviations (`BT`) rely on the reviewer only. |
| A5-F4 | minor | auto-fix | SKILL.md:214-216 | E5 on the file name has no remediation (Edit cannot rename); lint loop unbounded. |
| A5-F5 | minor | auto-fix | SKILL.md "Write the draft" | Writing tool not named; fr-1 wrote the draft with a Bash heredoc (an `EOF` line in pasted client text would end it). Name the Write tool. |
| A5-F6 | minor | no-op | evidence/ | `/Users/samuel` paths; pre-publication scrub (Phase 7 D-10). |
| A5-F7 | minor | no-op | summary.tsv; doctrine-reviewer.md:21-22 | Evidence does not discriminate leaks (baseline also `leak=no`); no adversarial scenario; reviewer's read list is prose only. |
| A5-F8 | minor | ask-user (Q13) | scripts/lint.py:88-90 | A non-empty `.gitkeep` under `outbound/` escapes E5 (LINT-01 skips `.gitkeep`). |

Samuel asked 2026-10-11 (Q13) whether to harden E5 or accept A5-F2/F3/F8 as debt.
