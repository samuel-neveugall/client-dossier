---
description: Lint the nearest client dossier with scripts/lint.py (read-only) and report every finding
argument-hint: "[path inside the dossier]"
---

Run the client-dossier linter and report its output and exit code verbatim. Fix nothing.

If an argument was given, it is a path: refuse it if it contains a single quote or a line break.
Otherwise run, with `--` before the path (so a path starting with `-` is never read as an option) and the path inside single quotes (or `.` when none was given):

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/lint.py" -- '<path>'
```

Exit codes:

- 0 no error (warnings allowed)
- 1 at least one error
- 2 no `dossier.yaml` found upward or unreadable
- 3 internal error

The path argument was: $ARGUMENTS
