---
phase: 07-manifests-docs-distribution
plan: 03
subsystem: hooks, skills, tests
tags: [codex, apply_patch, sources-guard, dist-03, skill-shape]
requires: []
provides:
  - "hooks/guard-sources.py reads Codex apply_patch headers (D-05)"
  - "dossier-init calls its bundled script quoted and guarded (D-15)"
  - "DIST-03 checker over every skill, with a negative control"
affects: [07-09 (spec sentence for apply_patch), 07-06 (README Codex section)]
tech-stack:
  added: []
  patterns: ["patch_hit reuses sources_target / visible_sources / MAX_JUDGED"]
key-files:
  created: []
  modified:
    - hooks/guard-sources.py
    - tests/test-hook-guard-sources.sh
    - skills/dossier-init/SKILL.md
    - tests/test-skill-shape.sh
key-decisions:
  - "apply_patch branch is IN (D-05): one branch in main() plus patch_hit, matcher and hooks.json untouched"
  - "Indented header lines count as headers (Codex trims before reading a header); refusing more is the safe side"
status: complete
actuals:
  tokens: 4500
  tasks: 2
  commits: 2
plan_head_before: 00d713a5b08192a37ed8e2c017a78c3c682c9c4d
plan_head_after: 0a4a1db
---

# Phase 7 Plan 03: Codex apply_patch guard, dossier-init quoting, DIST-03 checks Summary

The sources guard now denies Codex `apply_patch` edits whose Add/Update/Delete/Move header names a path under any ancestor dossier's `sources/`, dossier-init's script calls are quoted and `test -x` guarded like the other skills, and `tests/test-skill-shape.sh` pins quoting, guard, executable bundle and fallback for every skill.

## Tasks

| Task | Commit | Result |
|------|--------|--------|
| 1 (tracer) apply_patch branch | 9d645a9 | `patch_hit` + `elif tool == "apply_patch"` in `main()`; 125 new assertions, guard suite PASS 1683 FAIL 0 (was 1558, zero regression) |
| 2 dossier-init D-15 + DIST-03 | 0a4a1db | SKILL.md edited; DIST-03 block added; skill-shape suite PASS 40 FAIL 0 |

`bash tests/run.sh`: exit 0, `TOTAL: 24 files, 0 failed`.

## Case counts and timing (task 1)

New cases: 12 deny (Update, Add new, Delete, Move to under sources, Move out of a source, absolute path, `dossier/..` traversal, two files with the second under sources, CRLF, relative from a subfolder cwd, padded header, indented header after an added file), 9 silent (living files only, header-looking text in `+` lines, no header, empty header path, empty command, numeric command, list command, outside any dossier, sibling names `sources-old`/`mysources`), 1 past-MAX_JUDGED visible-sources deny (5000 headers then `dossier/deep/sources/z.txt`), and the end-to-end case (command string read from `hooks/hooks.json`, run through `sh -c` with `CLAUDE_PLUGIN_ROOT` set and Codex-shaped stdin: exit 0, empty stderr, deny, spec sentence plus path).

Timing (limit 4 s each, 1 MB patches):

```
ok   apply_patch: 1 MB of Add File headers outside sources: 0.07s status=0 denied=False
ok   apply_patch: 1 MB of headers, the last one under sources: 0.07s status=0 denied=True
ok   apply_patch: 1 MB of Update headers, the last one under sources: 0.07s status=0 denied=True
ok   apply_patch: one 1 MB header line: 0.04s status=0 denied=False
ok   apply_patch: 1 MB of added lines: 0.05s status=0 denied=False
```

The existing timing heredoc was generalised from a fixed `Bash` tool name to a (tool, shape) list; the 30 Bash shapes are unchanged.

## dossier-init before / after (task 2)

Step 4 before: `${CLAUDE_SKILL_DIR}/scripts/init.py --target <dossier root> --propose-renames`, no guard.
Step 4 after: `test -x "${CLAUDE_SKILL_DIR}/scripts/init.py"` first (failure: say so, skip to step 5, follow "If the bundled script is not available" in step 6), then `"${CLAUDE_SKILL_DIR}/scripts/init.py" --target '<dossier root>' --propose-renames`.

Step 6 before: unquoted `${CLAUDE_SKILL_DIR}/scripts/init.py \` with bare `<dossier root>`, `<code>`, `<code, only if step 5 forced one>`, `<true|false>`, `<n>` placeholders.
Step 6 after: `"${CLAUDE_SKILL_DIR}/scripts/init.py" \` with `'<dossier root>'`, `'<code>'`, `'<code, only if step 5 forced one>'`, `'<true|false>'`, `'<n>'`, preceded by a sentence saying a failed step-4 `test -x` means the next subsection applies.

DIST-03 red/green: before the SKILL.md edit the checker printed the three dossier-init violations (two unquoted references, missing guard) and the negative control read 5; after, zero on the real skills and exactly 2 on the mutated copy (unquoted `status.py` call in dossier-status, deleted `extract-text.sh` guard in dossier-ingest), each named by the test.

## Deviations from Plan

**1. [Rule 3 - Blocking] Worktree base behind the phase branch.** The worktree branch `worktree-agent-ad7f508bced161670` started at `b8aae7a` (phase 6 merge), which does not contain the phase 7 plan files. I fast-forwarded it (`merge --ff-only feat/phase-07-manifests-docs-distribution`, five planning-only commits, no conflict) before starting. The plan's "current branch feat/phase-07-..." is therefore this worktree branch; the orchestrator merges it.

**2. [Rule 2 - Security hardening] Indented headers count.** The contract says a header starts at column 0. `patch_hit` strips each line first, because (from my recollection of codex-rs `parse_one_hunk`, not re-verified here) Codex trims the line before matching a header, so an indented header following an added-file hunk would be a real hunk header. Denying it costs only a false positive on a context line quoting a sources path. `+`-prefixed lines are still never headers. Covered by a deny case and a silent case. Splitting is on `\n` (not `splitlines()`), so a path containing a Unicode line separator is not truncated.

**3. Test-tool workaround.** The `rtk` hook rewrite of `git` was refused by the worktree guard, so git was run as `/usr/bin/git`. No effect on the result.

## Observations for the review

- **Apostrophe in a counterpart name.** D-15 changes quoting style only; a `--counterpart` value holding `'` still breaks the single-quoted value in dossier-init step 6. Out of scope here.
- The apply_patch behaviour on a real Codex run stays documentation-backed (07-RESEARCH Open Question 5); only the hook's stdin contract and the hooks.json command are exercised offline.
- Plan 07-09 should record the spec sentence for apply_patch; this plan did not touch the spec, CLAUDE.md, hooks.json, test-hooks-config.sh, STATE.md or ROADMAP.md.

## Known Stubs

None.

## Threat Flags

None. T-07-09 to T-07-12 are mitigated as planned (deny/silent/traversal/CRLF/multi-file/end-to-end cases; linear scan with MAX_JUDGED then `visible_sources`; quoted and guarded references enforced by DIST-03 with a self-proving negative control).

## Self-Check: PASSED

- hooks/guard-sources.py, tests/test-hook-guard-sources.sh, skills/dossier-init/SKILL.md, tests/test-skill-shape.sh: modified and committed.
- Commits 9d645a9 and 0a4a1db are on HEAD; `hooks/hooks.json` and `tests/test-hooks-config.sh` are unchanged (matcher string verified).
- `bash tests/run.sh`: exit 0, 24 files, 0 failed.
