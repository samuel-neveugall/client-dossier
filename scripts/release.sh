#!/usr/bin/env bash
# scripts/release.sh — cut a release of client-dossier, locally (DIST-07, D-09).
#
# Usage:  scripts/release.sh <version>      (a semantic version such as 1.0.0)
#
# Run from anywhere inside a clean checkout. In one run it:
#   - sets "version" in .claude-plugin/plugin.json and .codex-plugin/plugin.json,
#   - sets "version" on the marketplace entries that already carry one
#     (.claude-plugin/marketplace.json, .agents/plugins/marketplace.json) and
#     leaves entries without one alone,
#   - inserts "## [<version>] - <today>" under "## [Unreleased]" in CHANGELOG.md,
#   - commits those five files as "chore(release): v<version>",
#   - creates the annotated tag v<version>.
#
# It only creates a LOCAL tag. It never contacts a remote or the network: pushing the
# tag, publishing to a marketplace and making the repository public each need
# Samuel's explicit approval (D-01).
#
# It refuses, changing nothing: a wrong argument count, a version that is not a
# semantic version, a dirty working tree, an existing tag for that version, two
# manifests that disagree, a manifest already at that version, a CHANGELOG without
# exactly one "## [Unreleased]" heading or already holding the new heading.
#
# Exit codes: 0 tagged, 1 refused.
# Bash 3.2 compatible (no arrays); python3 standard library only.
set -euo pipefail

die() {
  echo "release: $1" >&2
  exit 1
}

CLAUDE_MANIFEST=.claude-plugin/plugin.json
CODEX_MANIFEST=.codex-plugin/plugin.json
CLAUDE_MARKET=.claude-plugin/marketplace.json
CODEX_MARKET=.agents/plugins/marketplace.json
CHANGELOG=CHANGELOG.md

# rollback — put the five files back to HEAD when the commit fails (the tree was
# verified clean at the start, so nothing of the maintainer's is lost).
rollback() {
  git reset -q HEAD -- "$CLAUDE_MANIFEST" "$CODEX_MANIFEST" "$CLAUDE_MARKET" "$CODEX_MARKET" "$CHANGELOG" >/dev/null 2>&1 || true
  git checkout -q -- "$CLAUDE_MANIFEST" "$CODEX_MANIFEST" "$CLAUDE_MARKET" "$CODEX_MARKET" "$CHANGELOG" >/dev/null 2>&1 || true
}

# need FILE — the file exists in the checkout.
need() {
  [ -f "$1" ] || die "missing file: $1"
}

# 1. exactly one argument
[ "$#" -eq 1 ] || die "usage: scripts/release.sh <version> (exactly one semantic version, for example 1.0.0)"
version=$1

command -v python3 >/dev/null 2>&1 || die "python3 is required"

# 2. the official semver.org regex, on argv only, before the value is used anywhere
python3 -I - "$version" <<'PY' || die "not a semantic version: $(printf '%q' "$version")"
import re
import sys

SEMVER = (
    r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)"
    r"(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)"
    r"(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?"
    r"(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?"
)
sys.exit(0 if re.fullmatch(SEMVER, sys.argv[1], re.ASCII) else 1)
PY

# 3. work from the top of the checkout
top=$(git rev-parse --show-toplevel 2>/dev/null) || die "not inside a git repository"
cd "$top"

# 4. the five files exist
need "$CLAUDE_MANIFEST"
need "$CODEX_MANIFEST"
need "$CLAUDE_MARKET"
need "$CODEX_MARKET"
need "$CHANGELOG"

# 5. clean tree
[ -z "$(git status --porcelain --untracked-files=normal)" ] || die "working tree is not clean; commit first"

# 6. no tag for this version yet
if git rev-parse -q --verify "refs/tags/v$version" >/dev/null 2>&1; then
  die "tag v$version already exists"
fi

# 7. load, check and compute everything in memory; write only when every check passed
python3 -I - "$version" "$CLAUDE_MANIFEST" "$CODEX_MANIFEST" "$CLAUDE_MARKET" "$CODEX_MARKET" "$CHANGELOG" <<'PY'
import datetime
import json
import os
import re
import stat
import sys
import tempfile

version = sys.argv[1]
claude_manifest, codex_manifest, claude_market, codex_market, changelog = sys.argv[2:7]


def fail(message):
    sys.stderr.write("release: " + message + "\n")
    sys.exit(1)


def read_text(path):
    try:
        with open(path, encoding="utf-8", newline="") as handle:
            return handle.read()
    except (OSError, ValueError) as exc:
        fail("cannot read %s: %s" % (path, exc))


def load_json(path):
    try:
        data = json.loads(read_text(path))
    except ValueError as exc:
        fail("%s is not valid JSON: %s" % (path, exc))
    if not isinstance(data, dict):
        fail("%s is not a JSON object" % path)
    return data


def dump(data):
    return json.dumps(data, indent=2, ensure_ascii=False) + "\n"


def write_atomic(path, text):
    mode = stat.S_IMODE(os.stat(path).st_mode)
    handle, tmp = tempfile.mkstemp(dir=os.path.dirname(path) or ".", prefix=".release-", suffix=".tmp")
    try:
        with os.fdopen(handle, "w", encoding="utf-8", newline="") as out:
            out.write(text)
        os.chmod(tmp, mode)
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


claude = load_json(claude_manifest)
codex = load_json(codex_manifest)
markets = [(claude_market, load_json(claude_market)), (codex_market, load_json(codex_market))]
log = read_text(changelog)

claude_version = claude.get("version")
codex_version = codex.get("version")
if claude_version is None or codex_version is None:
    fail("a plugin manifest has no version field")
if claude_version != codex_version:
    fail("the two manifests disagree: %s vs %s" % (claude_version, codex_version))
if claude_version == version:
    fail("already at %s" % version)

unreleased = r"^## \[Unreleased\][ \t]*$"
if len(re.findall(unreleased, log, re.M)) != 1:
    fail("%s must hold exactly one '## [Unreleased]' heading" % changelog)
if re.search(r"^## \[" + re.escape(version) + r"\]", log, re.M):
    fail("%s already holds a '## [%s]' heading" % (changelog, version))

today = datetime.date.today().isoformat()
heading = "## [Unreleased]\n\n## [%s] - %s" % (version, today)
new_log = re.sub(unreleased, lambda _match: heading, log, count=1, flags=re.M)

claude["version"] = version
codex["version"] = version
writes = [(claude_manifest, dump(claude)), (codex_manifest, dump(codex))]

for path, data in markets:
    entries = data.get("plugins")
    changed = False
    if isinstance(entries, list):
        for entry in entries:
            if isinstance(entry, dict) and "version" in entry:
                entry["version"] = version
                changed = True
    if changed:
        writes.append((path, dump(data)))

writes.append((changelog, new_log))
for path, text in writes:
    write_atomic(path, text)
PY

# 8. commit exactly those five paths
git add -- "$CLAUDE_MANIFEST" "$CODEX_MANIFEST" "$CLAUDE_MARKET" "$CODEX_MARKET" "$CHANGELOG"
if ! git commit -q -m "chore(release): v$version" -- "$CLAUDE_MANIFEST" "$CODEX_MANIFEST" "$CLAUDE_MARKET" "$CODEX_MARKET" "$CHANGELOG"; then
  rollback
  die "the commit failed; the five files were restored"
fi

# 9. annotated tag, local only
git tag -a "v$version" -m "client-dossier $version"

# 10. report
echo "release: tagged v$version locally. Nothing was pushed."
