#!/usr/bin/env bash
# tests/dist/install-skills.sh — the bare-skills install check (DIST-03, D-17).
#
# A harness that only reads Agent Skills (no plugin system) gets skills/ and
# nothing else: no shared scripts/lint.py, no hooks, no agents. This check
# proves that install leaves every skill folder whole and that the copied
# private scripts work on their own with the linter reported unavailable:
#   --via copy        plain `cp -R` of each skills/<name>/ into the project's
#                     .claude/skills/ and .agents/skills/ (no third-party code);
#   --via skills-cli  the `skills` CLI (npm package), pinned and gated (below).
# Both routes start from a fresh `git clone` of HEAD, run inside one mktemp
# root with HOME under it, and compare Samuel's real configuration and skills
# folders before and after (D-17).
#
# SUPPLY CHAIN. The `skills` package was flagged SUS (too new) by the research.
# The agent-run gate `skills_registry_gate` replaces a human checkpoint: it
# reads registry metadata only (`npm view`, no code executed) and refuses unless
# the pinned version exists, is at least MIN_AGE_DAYS old, has no preinstall,
# install or postinstall script, points at github.com/vercel-labs/skills, is
# not deprecated, carries a SLSA provenance attestation and was published by
# GitHub Actions. The pin is the most recent version published more than 14
# days before the check (the newest releases were skipped on purpose). The CLI
# is only ever run as `npm exec --yes --package=<pin> -- skills ...` with
# telemetry off, lifecycle scripts disabled for the whole tree, dependencies
# resolved as of the pin's cut-off date, and a temporary HOME. The gate runs
# before every skills-CLI run; a refusal stops that route (exit 2) and the copy
# route stays available. DIST_SKILLS_SPEC overrides the pin for the refusal
# check only (never set it as a default).
#
# Free: no login, no model call. It installs HEAD only, so commit first.
# Exit codes: 0 pass, 1 gate not met, 2 harness error (a gate refusal included).
# Usage: bash tests/dist/install-skills.sh [--via skills-cli|copy] [--registry-only]
# Never run by tests/run.sh (the folder tests/dist/ is not globbed): run by the
# agent, the registry record kept under the phase's evidence/dist/ folder.
set -u

# shellcheck source=./lib-dist.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib-dist.sh"

# The pinned package spec: one variable, one default.
SKILLS_SPEC="${DIST_SKILLS_SPEC:-skills@1.7.0}"
# Resolve every dependency of the CLI as of this date (a few days after the pin
# was published, well before the newest releases).
SKILLS_BEFORE="${DIST_SKILLS_BEFORE:-2026-09-27T00:00:00Z}"
MIN_AGE_DAYS=14

VIA="skills-cli"
REGISTRY_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --via)
      [ $# -ge 2 ] || { echo "usage: --via needs skills-cli or copy" >&2; exit 2; }
      VIA="$2"
      case "$VIA" in
        skills-cli | copy) ;;
        *) echo "usage: --via takes skills-cli or copy, not $VIA" >&2; exit 2 ;;
      esac
      shift 2
      ;;
    --registry-only)
      REGISTRY_ONLY=1
      shift
      ;;
    *)
      echo "usage: bash tests/dist/install-skills.sh [--via skills-cli|copy] [--registry-only]" >&2
      exit 2
      ;;
  esac
done

dist_init install-skills

command -v python3 >/dev/null 2>&1 || scenario_die "python3 not found on PATH"

# skills_registry_gate — prints the registry record of $SKILLS_SPEC, one field
# per line, then the verdict. Returns 0 on `verdict: ok`, 1 on refused; a
# network or npm failure stops the harness (exit 2). Metadata only: nothing
# from the package is downloaded, installed or run. Needs dist_init.
skills_registry_gate() {
  local name version meta="$DIST_ROOT/registry-meta.json" times="$DIST_ROOT/registry-time.json"
  command -v npm >/dev/null 2>&1 || scenario_die "npm not found on PATH"
  name="${SKILLS_SPEC%@*}"
  version="${SKILLS_SPEC##*@}"
  (cd "$DIST_ROOT/cwd" && HOME="$DIST_ROOT/home" npm_config_update_notifier=false \
    npm_config_fund=false npm_config_audit=false npm view "$SKILLS_SPEC" --json) \
    >"$meta" 2>"$DIST_ROOT/registry-err.txt" \
    || scenario_die "npm view $SKILLS_SPEC failed: $(head -c 300 "$DIST_ROOT/registry-err.txt" | tr '\n' ' ')"
  (cd "$DIST_ROOT/cwd" && HOME="$DIST_ROOT/home" npm_config_update_notifier=false \
    npm_config_fund=false npm_config_audit=false npm view "$name" time --json) \
    >"$times" 2>"$DIST_ROOT/registry-err.txt" \
    || scenario_die "npm view $name time failed: $(head -c 300 "$DIST_ROOT/registry-err.txt" | tr '\n' ' ')"
  python3 -I - "$SKILLS_SPEC" "$version" "$meta" "$times" "$MIN_AGE_DAYS" <<'PY'
import datetime
import json
import sys

spec, want, meta_path, time_path, min_age = sys.argv[1:6]
min_age = int(min_age)
with open(meta_path, encoding="utf-8") as handle:
    meta = json.load(handle)
with open(time_path, encoding="utf-8") as handle:
    times = json.load(handle)
if isinstance(meta, list):
    meta = meta[-1]

now = datetime.datetime.now(datetime.timezone.utc)
version = str(meta.get("version", ""))
published = times.get(version, "")
age = "unknown"
age_days = -1
if published:
    stamp = datetime.datetime.strptime(published, "%Y-%m-%dT%H:%M:%S.%fZ")
    age_days = (now.replace(tzinfo=None) - stamp).days
    age = str(age_days)
repo = meta.get("repository") or {}
repository = repo.get("url", "") if isinstance(repo, dict) else str(repo)
deprecated = meta.get("deprecated") or "no"
scripts = meta.get("scripts") or {}
lifecycle = [s for s in ("preinstall", "install", "postinstall") if s in scripts]
npm_user = meta.get("_npmUser") or {}
if isinstance(npm_user, dict):
    publisher = str(npm_user.get("name", "")).strip()
else:
    publisher = str(npm_user).split("<")[0].strip()
if "<" in publisher:
    publisher = publisher.split("<")[0].strip()
dist = meta.get("dist") or {}
provenance = ((dist.get("attestations") or {}).get("provenance") or {}).get("predicateType", "none")

failed = []
if version != want:
    failed.append("version is " + version + ", not " + want)
if lifecycle:
    failed.append("lifecycle scripts " + " ".join(lifecycle))
if "github.com/vercel-labs/skills" not in repository:
    failed.append("repository is not github.com/vercel-labs/skills")
if deprecated != "no":
    failed.append("package is deprecated")
if provenance != "https://slsa.dev/provenance/v1":
    failed.append("no SLSA provenance attestation")
if publisher != "GitHub Actions":
    failed.append("publisher is not GitHub Actions")
if age_days < min_age:
    failed.append("published " + age + " days ago, under " + str(min_age))

print("checked_at: " + now.strftime("%Y-%m-%dT%H:%M:%SZ"))
print("package: " + spec)
print("version: " + version)
print("published: " + (published or "unknown"))
print("age_days: " + age)
print("age_rule: at least " + str(min_age) + " days")
print("repository: " + repository)
print("deprecated: " + str(deprecated))
print("lifecycle_scripts: " + (" ".join(lifecycle) if lifecycle else "none"))
print("publisher: " + publisher)
print("provenance: " + provenance)
if failed:
    print("verdict: refused (" + "; ".join(failed) + ")")
    sys.exit(1)
print("verdict: ok")
PY
}

if [ "$REGISTRY_ONLY" -eq 1 ]; then
  RECORD="$(skills_registry_gate)"
  GATE_RC=$?
  printf '%s\n' "$RECORD"
  [ "$GATE_RC" -eq 0 ] && exit 0
  exit 2
fi

scenario_die "install routes not written yet"
