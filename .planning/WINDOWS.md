---
schema_version: 1
open_count: 2
waived_count: 0
fixed_count: 0
total_count: 2
last_updated: 2026-09-16T17:54:14.478Z
---

# Broken Windows Ledger

> Cross-phase defect register. With `workflow.windows_enforce` enabled, `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | 01 | deviation | .claude-plugin/plugin.json |  | claude plugin validate . --strict exits 1 (author + CLAUDE.md-at-root warnings) while the manifest must stay at exactly 3 keys per this plan's own acceptance check; unresolved, needs a human/planner decision before Phase 7 manifests | open |  | 2026-09-16T17:42:04.517Z |  |
| 2 | 01 | deviation | skills/dossier-init/scripts/init.py |  | Global vibeflow 300-line file-size guard hook (not part of this project) forced tracing debt via vibeflow:allow-large-file marker instead of restructuring init.py mid-plan-01-02; TEMPLATE_MAP growth is a locked downstream contract | open |  | 2026-09-16T17:54:14.478Z |  |

````json
[
  {
    "id": 1,
    "kind": "deviation",
    "phase": "01",
    "file": ".claude-plugin/plugin.json",
    "line": null,
    "description": "claude plugin validate . --strict exits 1 (author + CLAUDE.md-at-root warnings) while the manifest must stay at exactly 3 keys per this plan's own acceptance check; unresolved, needs a human/planner decision before Phase 7 manifests",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-16T17:42:04.517Z",
    "resolved_at": null,
    "milestone": null
  },
  {
    "id": 2,
    "kind": "deviation",
    "phase": "01",
    "file": "skills/dossier-init/scripts/init.py",
    "line": null,
    "description": "Global vibeflow 300-line file-size guard hook (not part of this project) forced tracing debt via vibeflow:allow-large-file marker instead of restructuring init.py mid-plan-01-02; TEMPLATE_MAP growth is a locked downstream contract",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-16T17:54:14.478Z",
    "resolved_at": null,
    "milestone": null
  }
]
````
