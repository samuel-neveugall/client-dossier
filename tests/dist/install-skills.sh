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
# days before the check (skills@1.7.0; the newest releases were skipped on
# purpose, the record is evidence/dist/skills-1.7.0-registry.txt). The CLI
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

command -v git >/dev/null 2>&1 || scenario_die "git not found on PATH"

BEFORE="$(dist_real_snapshot)"

CLONE="$DIST_ROOT/src/repo"
dist_clone_head "$CLONE"
PROJECT="$DIST_ROOT/cwd/project"
mkdir -p "$PROJECT" || scenario_die "cannot create $PROJECT"

SKILL_NAMES=""
for dir in "$CLONE"/skills/*/; do
  [ -f "${dir}SKILL.md" ] || continue
  SKILL_NAMES="$SKILL_NAMES $(basename "$dir")"
done
[ -n "$SKILL_NAMES" ] || scenario_die "the clone holds no skills/<name>/SKILL.md"

# --- the install route -------------------------------------------------------
echo "route: $VIA"
if [ "$VIA" = "copy" ]; then
  for name in $SKILL_NAMES; do
    for target in .claude/skills .agents/skills; do
      mkdir -p "$PROJECT/$target" || scenario_die "cannot create $PROJECT/$target"
      cp -R "$CLONE/skills/$name" "$PROJECT/$target/$name" \
        || scenario_die "cp -R of skills/$name into $target failed"
    done
  done
  dist_ok "copied each skills/ folder into .claude/skills/ and .agents/skills/"
else
  RECORD="$(skills_registry_gate)"
  GATE_RC=$?
  printf '%s\n' "$RECORD" | dist_redact
  if [ "$GATE_RC" -ne 0 ]; then
    scenario_die "registry gate refused $SKILLS_SPEC: $(printf '%s\n' "$RECORD" | grep '^verdict:' | tail -1)"
  fi
  dist_ok "registry gate ok for $SKILLS_SPEC"
  command -v npm >/dev/null 2>&1 || scenario_die "npm not found on PATH"
  CLI_RC=0
  CLI_OUT="$(cd "$PROJECT" && HOME="$DIST_ROOT/home" DISABLE_TELEMETRY=1 DO_NOT_TRACK=1 \
    npm_config_ignore_scripts=true npm_config_update_notifier=false npm_config_fund=false \
    npm_config_audit=false npm_config_before="$SKILLS_BEFORE" \
    npm exec --yes --package="$SKILLS_SPEC" -- skills add "$CLONE" --skill '*' \
    --agent claude-code codex cursor gemini-cli opencode github-copilot --copy -y 2>&1)" || CLI_RC=$?
  echo "\$ npm exec --yes --package=$SKILLS_SPEC -- skills add <clone> --skill '*' --agent ... --copy -y"
  printf '%s\n' "$CLI_OUT" | sed $'s/\033\\[[0-9;?]*[A-Za-z]//g' | dist_redact
  if [ "$CLI_RC" -eq 0 ]; then
    dist_ok "skills add exits 0"
  else
    dist_bad "skills add failed (exit $CLI_RC)"
  fi
fi

# --- every skill folder is whole under both skills folders -------------------
for name in $SKILL_NAMES; do
  for target in .claude/skills .agents/skills; do
    dest="$PROJECT/$target/$name"
    if [ -f "$dest/SKILL.md" ]; then
      dist_ok "$target/$name/SKILL.md exists"
    else
      dist_bad "$target/$name/SKILL.md is missing"
      continue
    fi
    for file in "$CLONE/skills/$name/scripts"/*; do
      [ -f "$file" ] || continue
      rel="scripts/$(basename "$file")"
      if [ -f "$dest/$rel" ] && [ -x "$dest/$rel" ]; then
        dist_ok "$target/$name/$rel exists and is executable"
      else
        dist_bad "$target/$name/$rel is missing or not executable"
      fi
    done
  done
done
for target in .claude/skills .agents/skills; do
  for lang in en fr; do
    if [ -d "$PROJECT/$target/dossier-init/templates/$lang" ]; then
      dist_ok "$target/dossier-init/templates/$lang exists"
    else
      dist_bad "$target/dossier-init/templates/$lang is missing"
    fi
  done
done

# --- nothing else: what a bare install loses ---------------------------------
EXTRA="$(find "$PROJECT" \( -name lint.py -o -name hooks.json -o -name fact-extractor.md \
  -o -name doctrine-reviewer.md \) 2>/dev/null)"
if [ -z "$EXTRA" ]; then
  dist_ok "no lint.py, hooks.json, fact-extractor.md or doctrine-reviewer.md under the project folder"
else
  dist_bad "the project folder holds files a bare install must not carry: $(printf '%s' "$EXTRA" | dist_redact | tr '\n' ' ')"
fi

# --- the copied scripts work on their own ------------------------------------
DOSSIER="$DIST_ROOT/dossier"
mkdir -p "$DOSSIER" || scenario_die "cannot create $DOSSIER"
git -C "$DOSSIER" init -q || scenario_die "git init failed in the dossier folder"
INIT="$PROJECT/.claude/skills/dossier-init/scripts/init.py"
STATUS="$PROJECT/.claude/skills/dossier-status/scripts/status.py"

INIT_RC=0
INIT_OUT="$(cd "$DIST_ROOT/cwd" && HOME="$DIST_ROOT/home" python3 -I "$INIT" \
  --target "$DOSSIER" --language en \
  --counterpart 'Jane Doe|Head of IT|jane@example.com' 2>&1)" || INIT_RC=$?
echo "\$ python3 <project>/.claude/skills/dossier-init/scripts/init.py --target <dossier> --language en --counterpart ..."
printf '%s\n' "$INIT_OUT" | dist_redact
if [ "$INIT_RC" -eq 0 ]; then
  dist_ok "the copied init.py exits 0"
else
  dist_bad "the copied init.py failed (exit $INIT_RC)"
fi
if [ -f "$DOSSIER/dossier.yaml" ]; then
  dist_ok "the copied init.py wrote dossier.yaml"
else
  dist_bad "the copied init.py did not write dossier.yaml"
fi

STATUS_RC=0
STATUS_OUT="$(cd "$DIST_ROOT/cwd" && HOME="$DIST_ROOT/home" python3 -I "$STATUS" \
  --json "$DOSSIER" 2>&1)" || STATUS_RC=$?
echo "\$ python3 <project>/.claude/skills/dossier-status/scripts/status.py --json <dossier>"
printf '%s\n' "$STATUS_OUT" | dist_redact | head -c 1500
echo
if [ "$STATUS_RC" -eq 0 ]; then
  dist_ok "the copied status.py exits 0"
else
  dist_bad "the copied status.py failed (exit $STATUS_RC)"
fi
STATUS_REPORT="$(printf '%s' "$STATUS_OUT" | python3 -I -c '
import json, sys
try:
    data = json.loads(sys.stdin.read())
except ValueError:
    print("bad\tstatus.py --json is not valid JSON")
    sys.exit(0)
lint = data.get("lint") if isinstance(data, dict) else None
if not isinstance(lint, dict) or "available" not in lint:
    print("bad\tthe JSON report has no lint.available field")
else:
    print(("ok" if lint["available"] is False else "bad")
          + "\tlint.available is " + json.dumps(lint["available"])
          + " (false expected: no plugin marker beside a bare copy)")
')"
while IFS=$'\t' read -r verdict text; do
  case "$verdict" in
    ok) dist_ok "$text" ;;
    bad) dist_bad "$text" ;;
  esac
done <<EOF
$STATUS_REPORT
EOF

# --- the real configuration and skills folders are untouched (D-17) ----------
if dist_real_unchanged "$BEFORE"; then
  dist_ok "real Claude Code, Codex, ~/.agents and ~/.claude/skills byte-identical"
else
  dist_bad "real configuration changed"
fi

dist_finish
