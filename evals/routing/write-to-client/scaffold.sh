#!/bin/bash
# evals/routing/write-to-client/scaffold.sh -- seed a minimal dossier with the
# plugin's own init.py. Runs in an empty workspace (claude plugin eval --scaffold);
# no network, nothing written outside the workspace.
set -eu
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
git init -q .
python3 "$root/skills/dossier-init/scripts/init.py" --target . --language en \
  --counterpart 'Jane Doe|Head of IT|jane@example.com' --confidential-name 'Globex' >/dev/null
git add -A
git -c user.name=eval -c user.email=eval@example.invalid commit -qm seed
