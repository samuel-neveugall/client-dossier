#!/bin/bash
# evals/routing/ingest-transcript/scaffold.sh -- seed a minimal dossier with the
# plugin's own init.py, then drop the call transcript beside it, untracked.
# Runs in an empty workspace (claude plugin eval --scaffold); no network,
# nothing written outside the workspace.
set -eu
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
git init -q .
python3 "$root/skills/dossier-init/scripts/init.py" --target . --language en \
  --counterpart 'Jane Doe|Head of IT|jane@example.com' --confidential-name 'Globex' >/dev/null
git add -A
git -c user.name=eval -c user.email=eval@example.invalid commit -qm seed
printf '%s\n' \
  '@00:00 Jane Doe: Thanks for joining, a quick recap of where we are.' \
  '@03:12 Jane Doe: The security review moves to 2026-10-24; we need your answers by 2026-10-20.' \
  '@07:45 Sam: We will send them by 2026-10-17.' \
  '@12:30 Jane Doe: Budget approval comes from the steering committee on 2026-10-27.' \
  > call-2026-10-10.txt
