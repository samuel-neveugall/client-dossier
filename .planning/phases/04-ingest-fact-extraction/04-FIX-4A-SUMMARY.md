# Phase 4 correction fix-4a (round 1 of 3)

Closes R4-M1..R4-m10 (04-REVIEW.md) and A4-F1..A4-F10 (04-SECURITY.md); none accepted as debt.
Commits: 7435893 (scripts and their tests), e4dbed2 (skill, agent, init skill, skill tests),
29d3715 (scenarios and harness helpers). Skill refinement rounds used: 0 of 2.

Evidence (paid, headless, plugin loaded; D-12 amended gate: GREEN needs a successful
`client-dossier:fact-extractor` dispatch):
- `evidence/green-plugin-r2/`: transcript, 3 runs, GREEN 3/3, `extractor_dispatched` yes 3/3.
- `evidence/pdf-plugin-r2/`: PDF, 1 run, GREEN 1/1, `extractor_dispatched` yes.
- A4-F10: in every run the subagent events (`parent_tool_use_id` set) hold only Read and Glob
  calls (transcript: 9 Read + 1 Glob per run; PDF: 9 Read), no tool_result in error. The harness
  allowlist did not need widening.
- Cost: transcript 0.2149 + 0.2138 + 0.2081 USD, PDF 0.2332 USD; total 0.870 USD, within
  the 1.5 USD budget.
