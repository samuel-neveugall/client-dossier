# Phase 7 — code review with security pass (revue-7, plans 07-01..07-07)

Range `b8aae7a..b17ba11`, full regime, isolated config dirs; vf-reviewer, 2026-10-11; persisted by the
mission manager. Verdict: **gaps_found** — 0 blocker, 2 major, 3 minor. Manifests valid and aligned
(0.1.0, `author` without e-mail, MIT, local marketplace sources, `.codex-plugin/plugin.json` present);
`release.sh` replayed in a scratch clone (success path, refusals for bad semver/injection/dirty
tree/existing tag, never pushes); guard `apply_patch` branch correct on the native path, imports and
fail-open kept; README accurate; eval honest (Sonnet 8/8, `write-to-client` → `dossier-draft` never
`dossier-ingest`); `git fsck` clean, 5 merges lossless, trailers on 31 commits; `tests/run.sh` 28/0.

| ID | Sev. | Action | Ref | Finding |
|---|---|---|---|---|
| R8-F1 | major | auto-fix | skills/dossier-init/SKILL.md:77,117-131 | An apostrophe in a value (`L'Oréal`, `O'Brien`, `accord de l'intéressé`) breaks the single-quoted call: the `|` splits into a pipeline, `init.py --counterpart LOréal` really runs, `confidential_names` protects "LOréal" — the confidentiality gate is silently neutralised and idempotence prevents repair. Fix: POSIX `'\''` escaping rule in the skill + test (bash round-trip). |
| R8-F2 | major | fix (D-16) | hooks/guard-sources.py:1329 | `apply_patch <<'EOF' … *** Update File: sources/…` through Bash is allowed (heredoc bodies stripped, `apply_patch` unknown verb). Fix: in the Bash branch also run `patch_hit` when the text holds `*** Begin Patch` or a patch header line. |
| R8-F3 | minor | no-op | README.md:68-72 | Claude pin syntax `owner/repo@v1.0.0` unverified (private repo, no tag); to check before publication. |
| R8-F4 | minor | no-op | guard-sources.py:1269-1306 | `*** Add File: sources/…` is denied too (symmetric with D-03); Phase 4 files sources through `file_source.py`, unaffected. |
| R8-F5 | minor | auto-fix | scripts/release.sh:192-199 | `git tag -a` failure after the commit leaves an untagged release commit (no rollback); a failure among the five atomic writes leaves a partial tree; no branch check. |

## Manager decision
R8-F2 is a reproduced fail-open path of the guard readable in the command's tokens, so it falls under
Samuel's 03 D-16 (fix every reproduced fail-open path, 2026-10-10), not the accepted D-04 class (D-17:
eval, interpreters, substitutions, variables, loops): fixed, no new question.
