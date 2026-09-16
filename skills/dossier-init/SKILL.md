---
name: dossier-init
description: Use when someone wants to start or set up a dossier for a client, partner, prospect or recruiter in this repository, or when a repository already holds calls, mails and deliverables about an external party but has no dossier.yaml yet. Also use to complete a dossier scaffold that already exists in this repository — re-running only adds what is missing, it never overwrites a living file.
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/init.py *)
---

# dossier-init

Scaffolds a `client-dossier` layout into the current repository: `dossier.yaml`, the four
top-level folders (`sources/`, `dossier/`, `knowledge/`, `outbound/`) with their documented
subfolders, the seven living files under `dossier/`, the `knowledge/CONTEXT.md` and
`knowledge/DOCTRINE.md` stubs, and one README per top-level folder.

## What it produces

- `dossier.yaml` — the ten configuration keys (version, language, counterparts,
  confidential names, consent, timestamps, date format, status-header setting,
  staleness window).
- The four top-level folders, each with a `.gitkeep` in every leaf folder the scaffold
  leaves empty, so an empty folder still survives a clone.
- The seven living files under `dossier/`, each opening with a `Last updated:` line and
  its "Updated when" rule.
- The knowledge stubs and the three top-level READMEs.

## How to run it

Run the bundled script through its skill-relative path — **never** a repository-relative
path, because this skill's working directory at invocation is the user's dossier
repository, not the plugin:

```
${CLAUDE_SKILL_DIR}/scripts/init.py --language <code> --counterpart '<Name>|<role>|<contact>' ...
```

Run it from the root of the repository the user wants scaffolded — the directory
containing (or that should contain) `dossier.yaml`. Every input the script needs is a
command-line argument; it never prompts.

## Rules

- **Idempotent, never destructive.** Re-running the script on an already-scaffolded
  repository completes only what is missing. It never truncates or overwrites an existing
  file — a living dossier is safe to run this against at any time.
- **Never commits.** The skill reports what it created and what it left alone (`created: `
  / `kept: ` per path); reviewing and committing the result is always the human's step.
- **English artefacts, localised content.** The script, this skill and their output paths
  are English; only the dossier's own content follows the language the caller configures.

## Scope of this skill today

This is the scaffold path for a single language and a single bundled template. The
judgement this skill will also own once the rest of the mechanics exist — inferring
language, asking one grouped question for whatever the caller did not supply, deriving the
confidential-name list, detecting and proposing renames on an existing repository, and
translating templates for a language with no bundled variant — is written once those
behaviours exist in the script, so the description here and the code never drift apart.
