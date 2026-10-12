# Phase 1: Scaffold & Templates - Research

**Researched:** 2026-09-16
**Domain:** Agent Skills packaging (bundled resources), Claude Code plugin manifest & local
loading, Markdown/YAML template structure derived from a real dossier repository
**Confidence:** HIGH on the two external-standard questions (cross-checked against official
Anthropic docs + the Agent Skills open standard); HIGH on the origin-repo structural
comparison (read directly from disk this session).

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Input collection (what `dossier-init` asks)**
- **D-01:** Arguments first, questions for the rest. Anything given as an argument or in the
  user's sentence (counterpart names, roles, language, confidential names) is used as is; the
  skill asks **one grouped question** only for what is missing. It never re-asks what it has.
- **D-02:** With nothing specified ("initialise un dossier"), the skill asks one minimal grouped
  question: counterpart(s) with role, and language. Everything else (confidential names, formats,
  `staleness_days`, `status_header`, `consent_*`) is derived or set to the spec §3.2 defaults.
  No placeholder-only scaffold.
- **D-03:** Language is inferred (conversation language, then an existing `CLAUDE.md`/`AGENTS.md`)
  and proposed as the default in the grouped question; the user confirms or changes it. Never
  silently English.
- **D-04:** `confidential_names` is derived from the counterpart names **plus their short forms**
  ("Acme Consulting" → "Acme"); the skill shows the resulting list and lets the user add or
  remove entries before writing.

**Scaffold mechanics (script vs prose)**
- **D-05:** The deterministic part (folders, `.gitkeep`, `dossier.yaml`, copying templates,
  READMEs, stubs) is done by a Python 3 standard-library script. The skill keeps the judgement:
  the grouped question, language inference, translation for unlisted languages, rename detection,
  the instructions-file pointer. — **Reversibility:** costly — the skill prose, the bash tests
  of Phase 2 and the inline fallback all assume a script exists; moving to prose-only rewrites
  all three.
- **D-06:** The script and the templates live **inside the skill folder**:
  `skills/dossier-init/scripts/init.py` and `skills/dossier-init/templates/`. The Agent Skills
  standard allows bundled resources, so they survive a bare-skills install. `scripts/lint.py`
  (shared by several skills) stays at the repository root `scripts/`, as in spec §4. The spec's
  architecture tree (§4, `templates/` at the root) is to be amended accordingly during this
  phase. — **Reversibility:** costly — every skill that references `templates/` or `init.py`
  paths, plus the README install instructions, would change.
- **D-07:** When the script is absent (bare-skills install, or a harness that cannot run
  Python), the skill contains the same procedure inline (the exact file list, folder list,
  `.gitkeep` rule, `dossier.yaml` shape) and says it is doing the script's job itself.
- **D-08:** Re-running `dossier-init` on an initialised dossier **completes without
  overwriting**: writes only what is missing, never touches an existing file, reports what was
  added. Idempotent and safe on a living dossier.

**Templates (content and language)**
- **D-09:** Templates ship in **two hand-maintained language variants**, `templates/en/` and
  `templates/fr/`, so French output is deterministic and testable. For any other configured
  language the skill translates from `en/` at scaffold time (spec §4.5 behaviour). Protocol
  keywords (`Last updated:`, status-header fields and values) are identical in every variant
  and never translated.
- **D-10:** The seven living files are **skeletons faithful to spec §2.2**: title, `Last updated:`
  line, the "Updated when" rule as an HTML comment, the sections listed in §2.2 (e.g. HISTORY:
  chronology, commitments in progress (ours / theirs), upcoming), and one example line. No
  sub-sections, no writing advice beyond the comment.
- **D-11:** The example fact line in each template is an **HTML comment**
  (`<!-- - Example: Jane Doe (Acme) asks for the deliverable by 2026-10-01 (call @12:34). -->`):
  visible when editing, invisible when rendered, ignored by the linter (so no spurious
  "line without a source" warning), nothing to delete.
- **D-12:** `knowledge/CONTEXT.md` and `knowledge/DOCTRINE.md` stubs carry **2-3 guiding
  questions per section as HTML comments** ("What do we never promise before scoping?", "Which
  vocabulary is banned?"). DOCTRINE keeps the two lists (what we say / what we never say) plus
  the vocabulary section.
- **D-13:** Template structure is **derived from the real origin repository**
  (`/Users/samuel/Documents/dev/Project-POC-RELATION-CLIENT`): the researcher reads its folder
  layout and the headings of its living files to make the French templates faithful and to
  check spec §2.2 against reality. **Its content is confidential and is never copied, quoted or
  used as example text**; only structure (folder names, file names, heading names, section order)
  is used. The scaffold's `sources/` layout follows the spec (`received/`, `transcripts/raw/`),
  not the origin's ad-hoc `internes/` and `plaquette/`.

**Adopting an existing repository (SCAF-06)**
- **D-14:** Detection of folders that already play a role uses a **table of known names (FR/EN)
  plus content hints**, then confirmation. Known names at least: `sources` / `sources`;
  `dossier` / `client` / `relation` / `relationship`; `knowledge` / `docs` / `connaissance(s)`;
  `outbound` / `communication` / `sortant`; subfolders `appels` / `calls`, `livrables` /
  `deliverables`, `mails`, `veille` / `watch`, `decisions`, `transcripts`, `raw`. Content hints:
  living files such as `ACTEURS.md` / `HISTORIQUE.md` / `TON.md`, files named `YYYY-MM-DD_slug`.
  The skill shows the proposed mapping (old path → fixed English name) and asks for confirmation
  before any rename. The origin repository is the reference case: `client/` → `dossier/`,
  `communication/{appels,livrables,mails}` → `outbound/{calls,deliverables,mails}`,
  `docs/{CONTEXTE.md,DOCTRINE.md,decisions,veille}` → `knowledge/{CONTEXT.md,DOCTRINE.md,decisions,watch}`,
  `client/{ACTEURS,APPRENTISSAGES,CANAUX,HISTORIQUE,QUESTIONS-OUVERTES,RELATION,TON}.md` →
  the seven English file names.
- **D-15:** After explicit confirmation the skill **executes the `git mv` commands** itself, then
  completes what is missing (D-08). Without confirmation it executes nothing. It **never commits**;
  the user reviews and commits.
- **D-16:** The protocol pointer is written to **`AGENTS.md` always** (created if absent,
  completed if present) **and to `CLAUDE.md` only if it already exists**. The section is
  delimited by marker comments (e.g. `<!-- client-dossier:start -->` … `<!-- client-dossier:end -->`)
  so that re-running init is idempotent and the section can be updated in place.
- **D-17:** Folders that play no dossier role (the origin's `pipeline/`, for instance) are left
  untouched and listed as "ignored" in the report.

### Claude's Discretion
- Exact wording of the grouped question and of the report printed at the end of init.
- The `.gitkeep` rule details (which leaf folders) follow spec §3.2; the script decides how to
  detect "empty".
- Internal structure of `init.py` (argument parsing, template copying, idempotence checks) as
  long as it is standard library only and callable from bash tests in Phase 2.
- Marker comment syntax for the instructions-file section.
- How the skill infers the conversation language.

### Deferred Ideas (OUT OF SCOPE)
- `pipeline/` of the origin repository (HTML → PDF rendering with fonts and design file):
  out of v1 scope per spec §9 D and §10; a later rendering plugin could hook into
  `outbound/deliverables/`.
- Whether `sources/` should get role subfolders beyond `received/` and `transcripts/`
  (the origin uses `internes/` and `plaquette/`): not changed in this phase; the spec layout
  stands. Revisit if ingest (Phase 4) needs it.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description (from `.planning/REQUIREMENTS.md`) | Research Support |
|----|-------------|------------------|
| SCAF-01 | `dossier-init` writes `dossier.yaml` with version, language, counterparts (name/role/contacts), confidential_names, consent_recorded, consent_source, timestamps format, date_format, status_header setting, staleness_days (default 7) | Spec §3.2 gives the exact YAML block verbatim (quoted in *Code Examples*). Security note: counterpart names are user input written into YAML — see *Security Domain* V5. |
| SCAF-02 | Four-folder layout with documented subfolders, a `.gitkeep` in each empty leaf | Spec §3.2 names the seven `.gitkeep` leaves verbatim (quoted below). Origin repo confirms the failure mode: its `communication/mails/` is empty and therefore invisible to `git clone`. |
| SCAF-03 | Seven living files from templates, each with `Last updated:` + "Updated when" comment | Spec §2.2 table = the seven files + their "Updated when" text. Origin-repo heading audit (below) confirms §2.2 section lists against reality, with three discrepancies flagged. |
| SCAF-04 | `knowledge/CONTEXT.md`, `knowledge/DOCTRINE.md` (two lists), one README per top-level folder (`dossier/`, `sources/`, `outbound/`) | Origin repo has `docs/CONTEXTE.md`, `docs/DOCTRINE.md` (last three headings match exactly), `client/README.md`, `communication/README.md`. It has **no** `sources/README.md` — that one is net-new. |
| SCAF-05 | Protocol-pointer section in `CLAUDE.md`/`AGENTS.md` | Spec §4.1 + §8 row 4. No external standard constrains this; marker-comment idempotence pattern recommended (see *Architecture Patterns* Pattern 3). |
| SCAF-06 | On an existing repo, detect same-role folders and propose `git mv` | Origin repo structure read this session → D-14 mapping verified, **one gap found** (`sources/internes`, `sources/plaquette`). |
| SCAF-07 | Templates authored in English structure; translated at scaffold time; protocol keywords stay English | Spec §3.2 + §4.5. D-09 (two hand-maintained variants) is a superset of §4.5 and satisfies it. |
| SCAF-08 | Minimal `.claude-plugin/plugin.json` so `claude --plugin-dir .` loads the plugin | **Answered below with citation.** Minimal manifest = `name` only (required); recommended `name` + `description` + `version`. |
</phase_requirements>

## Summary

The two open questions both resolve **in favour of the phase context's assumptions**, with
refinements.

**Question 1 (D-06, bundled resources).** A skill is a folder whose only required file is
`SKILL.md`; the Agent Skills open standard explicitly documents optional `scripts/`,
`references/` and `assets/` subfolders "plus additional files/directories", and Claude Code's
own plugin reference shows `scripts/` inside a plugin skill folder. Bare-skills installers
(`npx skills add`) copy or symlink **the whole skill folder**, so `skills/dossier-init/scripts/init.py`
and `skills/dossier-init/templates/` do survive that install path. Two refinements the planner
must absorb: (a) Claude Code exposes `${CLAUDE_SKILL_DIR}`, which expands to *the skill's own
subdirectory inside the plugin* — that is the correct way to reference `init.py` from
`SKILL.md` and from `allowed-tools`, and it is why D-06 works; (b) the open standard's canonical
name for a bundled static-resource folder is `assets/`, not `templates/`. `templates/` is
permitted ("additional files/directories") but is non-canonical — a naming decision, not a
blocker.

**Question 2 (SCAF-08, manifest).** `.claude-plugin/plugin.json` is in fact *optional*: with no
manifest, Claude Code auto-discovers `skills/`, `commands/`, `agents/`, `hooks/hooks.json`.
When present, **only `name` is required** (kebab-case, no spaces). The documented quickstart
manifest is `name` + `description` + `version` (semver) + optional `author` — exactly SCAF-08's
"minimal". No `marketplace.json` is needed for `--plugin-dir`. Three gotchas: only `plugin.json`
may live inside `.claude-plugin/` (never `skills/`, `agents/`, `hooks/`); plugin skills are
**namespaced** (`/client-dossier:dossier-init`), which changes how the spec's skill names are
invoked; and a directory with *neither* a manifest *nor* top-level plugin components is treated
as a **folder of plugins** rather than one plugin — which is precisely why shipping the manifest
in Phase 1 (SCAF-08) is load-bearing and not cosmetic.

**Structural comparison.** The origin repository's real layout matches D-13/D-14 almost exactly
— all seven living files present under `client/`, `communication/{appels,livrables,mails}`,
`docs/{CONTEXTE.md,DOCTRINE.md,decisions/,veille/}`, `pipeline/` to ignore. Four discrepancies
are flagged below, one of which (the unmapped `sources/internes/` + `sources/plaquette/`)
directly affects SCAF-06's stated acceptance case.

**Primary recommendation:** Keep D-06 as decided, but reference the script from `SKILL.md` via
`${CLAUDE_SKILL_DIR}/scripts/init.py` (not a hard-coded relative path), ship
`.claude-plugin/plugin.json` with `name` + `description` + `version`, and add
`claude plugin validate .` (available in the installed CLI, v2.1.273) as the mechanical
acceptance check for SCAF-08.

## Architectural Responsibility Map

The tiers here are the spec's own division of responsibility (§4: "skills carry the judgement,
scripts carry the mechanics, hooks carry the reminders"), not web tiers.

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Ask the grouped question, infer language (D-01…D-04) | Skill (`SKILL.md`) | — | Judgement; no regex can decide what the user meant. |
| Derive `confidential_names` short forms (D-04) | Skill | Script (writes the confirmed list) | Deriving "Acme" from "Acme Consulting" is judgement; writing the YAML is mechanics. |
| Create folders, `.gitkeep`, copy templates, write READMEs, write `dossier.yaml` (SCAF-01…04) | Script (`init.py`) | Skill (inline fallback, D-07) | Fully deterministic; must be testable from bash in Phase 2. |
| Idempotent "write only what is missing" (D-08) | Script | — | A filesystem existence check, not a judgement. |
| Detect same-role folders, propose mapping (SCAF-06) | Skill | Script (could emit candidates) | Name table + content hints + user confirmation = judgement. |
| Execute the confirmed `git mv` (D-15) | Skill (runs `git mv`) | — | Must follow an explicit human confirmation; never automated inside the script. |
| Translate templates to an unlisted language (SCAF-07) | Skill | Template (`en/` is the source) | Only the model can translate; templates are static. |
| Protocol pointer with markers (SCAF-05, D-16) | Script | Skill (decides *which* files exist) | Marker-delimited replace is mechanical once the target file is known. |
| Load the plugin from a working copy (SCAF-08) | Manifest (`.claude-plugin/plugin.json`) | — | Harness integration; nothing else can do it. |

## Standard Stack

This phase adds **zero external dependencies**. The stack is the runtime already required by
`CLAUDE.md` ("scripts Python 3 stdlib only, tests bash+python3 only").

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Python 3 standard library | 3.14.6 present locally; target ≥3.8 | `init.py` — folders, `.gitkeep`, template copy, `dossier.yaml` emission, marker-section insert | Project constraint in `CLAUDE.md`; guarantees the script runs on any machine with `python3` and no install step. `[VERIFIED: python3 --version → Python 3.14.6, run this session]` |
| `git` CLI | 2.50.1 present locally | `git mv` for SCAF-06 renames | Rename must be recorded as a rename so history survives. `[VERIFIED: git --version, run this session]` |
| Claude Code CLI | 2.1.273 present locally | `claude --plugin-dir .`, `claude plugin validate .` | Required by the ROADMAP's success criterion 1. `[VERIFIED: claude --version → 2.1.273, run this session]` |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `bash` | system | Phase 2 test runner calls `init.py` non-interactively | Keep `init.py` fully argument-driven (CONTEXT "Integration Points"). |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Hand-rolled YAML emission in `init.py` | `PyYAML` | Forbidden: `CLAUDE.md` mandates stdlib only. `dossier.yaml` is a fixed, tiny shape the script *writes* (it does not need to *parse* arbitrary YAML in this phase), so emission via an f-string template is adequate. Phase 2's `lint.py` needs the tiny YAML-subset parser the spec already prescribes. |
| `templates/` inside the skill | `assets/` inside the skill (open-standard canonical name) | `assets/` matches the Agent Skills spec's documented folder names; `templates/` is more self-describing for this domain. Both are legal. D-06 locked `templates/`; flagged as a naming-only open question. |
| Manifest at Phase 7 only | Manifest in Phase 1 (SCAF-08) | Without a manifest, a repo root with `skills/` at top level still loads as a plugin — but the plugin *name* (and therefore the `/client-dossier:` namespace) becomes implicit, and a repo root with no top-level components would load as a *folder of plugins*. Shipping the manifest now is the safe choice and is what SCAF-08 asks for. |

**Installation:** none. No package is installed by this phase.

## Package Legitimacy Audit

**Not applicable.** This phase installs no external packages in any ecosystem. `init.py` is
Python 3 standard library only; the test runner is bash + `python3`; the plugin manifest declares
no `dependencies`. The `skills` npm CLI (`npx skills add …`) appears in spec §8 as a *distribution*
path and is Phase 7's concern, not this phase's — it is never executed by the plugin.

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
user sentence / arguments ──► dossier-init SKILL.md  (judgement tier)
                                   │
                                   ├─ 1. infer language (conversation → CLAUDE.md/AGENTS.md)   [D-03]
                                   ├─ 2. collect what is missing, ONE grouped question         [D-01/D-02]
                                   ├─ 3. derive confidential_names short forms, confirm        [D-04]
                                   │
                                   ├─ 4. scan repo root for same-role folders
                                   │        │  name table (FR/EN) + content hints              [D-14]
                                   │        ▼
                                   │    proposed mapping  ──► HUMAN CONFIRMATION ──► git mv    [D-15]
                                   │        (no confirmation ⇒ nothing executed)
                                   │
                                   ├─ 5. choose template variant
                                   │        language ∈ {en, fr} ? templates/<lang>/
                                   │        else               ? templates/en/ + translate     [D-09]
                                   │
                                   ├─ 6. run  ${CLAUDE_SKILL_DIR}/scripts/init.py --…   (mechanics tier)
                                   │        │   script absent ⇒ skill performs the same
                                   │        │   procedure inline and says so                   [D-07]
                                   │        ▼
                                   │    ┌──────────────────────────────────────────────┐
                                   │    │ for each target path:                         │
                                   │    │   exists? ─ yes ─► skip, record "kept"        │  [D-08]
                                   │    │            └─ no ─► write, record "created"   │
                                   │    ├──────────────────────────────────────────────┤
                                   │    │ dossier.yaml │ 4 folders + 7 .gitkeep leaves  │
                                   │    │ 7 living files │ CONTEXT.md │ DOCTRINE.md     │
                                   │    │ 3 READMEs      │ marker section in AGENTS.md  │
                                   │    │                │ + CLAUDE.md iff it exists    │  [D-16]
                                   │    └──────────────────────────────────────────────┘
                                   │
                                   └─ 7. report: created / kept / renamed / ignored            [D-17]
                                            (never commits — human reviews)                   [D-15]

harness loading path:
  claude --plugin-dir .  ──► reads .claude-plugin/plugin.json (name: client-dossier)
                         ──► auto-discovers skills/ at plugin root
                         ──► /client-dossier:dossier-init   (namespaced)
  bare-skills install    ──► whole skills/dossier-init/ folder copied (scripts/ + templates/ ride along)
```

### Recommended Project Structure

Amends spec §4 per D-06 (this is the tree *this phase* creates; later phases add the rest):

```
client-dossier/
├── .claude-plugin/
│   └── plugin.json              # SCAF-08 — ONLY this file may live here
├── skills/
│   └── dossier-init/
│       ├── SKILL.md             # judgement: questions, language, rename proposal
│       ├── scripts/
│       │   └── init.py          # mechanics; referenced as ${CLAUDE_SKILL_DIR}/scripts/init.py
│       └── templates/           # D-06 (open standard would call this assets/)
│           ├── en/
│           │   ├── ACTORS.md  HISTORY.md  LEARNINGS.md  TONE.md
│           │   ├── CHANNELS.md  OPEN-QUESTIONS.md  RELATIONSHIP.md
│           │   ├── CONTEXT.md  DOCTRINE.md
│           │   └── README-dossier.md  README-sources.md  README-outbound.md
│           └── fr/              # same file names, French headings, English keywords
└── tests/                       # smoke test for init.py (Phase 2 owns the lint fixtures)
```

`scripts/lint.py` stays at the repository root in Phase 2, per spec §4 (shared by several
skills, referenced with `${CLAUDE_PLUGIN_ROOT}/scripts/lint.py`).

### Pattern 1: Bundled skill resources referenced with `${CLAUDE_SKILL_DIR}`

**What:** A plugin skill's own directory is addressable at runtime. `${CLAUDE_SKILL_DIR}`
expands to *the skill's subdirectory within the plugin*, not the plugin root — which is exactly
the address D-06 needs.
**When to use:** Every reference from `SKILL.md` to `scripts/init.py` or `templates/`.
**Example:**
```yaml
# Source: https://code.claude.com/docs/en/skills
---
name: render-chart
description: Render a chart from a CSV file
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/render.sh *)
---

Run `${CLAUDE_SKILL_DIR}/scripts/render.sh <csv-file>` to render the chart.
```
Applied to this phase: `allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/init.py *)` and, in the
body, `Run ${CLAUDE_SKILL_DIR}/scripts/init.py --language fr --counterpart …`.
Companion variables: `${CLAUDE_PLUGIN_ROOT}` (plugin install dir — for Phase 2's `scripts/lint.py`),
`${CLAUDE_PROJECT_DIR}` (project root), `${CLAUDE_PLUGIN_DATA}` (persists across plugin updates).
`[CITED: https://code.claude.com/docs/en/skills]` `[CITED: https://code.claude.com/docs/en/plugins-reference]`

### Pattern 2: Minimal plugin manifest for local development

**What:** The smallest manifest that makes `claude --plugin-dir .` load this repository as the
`client-dossier` plugin.
**When to use:** SCAF-08, committed in Phase 1.
**Example:**
```json
// Source: https://code.claude.com/docs/en/plugins (quickstart, verbatim shape)
{
  "name": "my-first-plugin",
  "description": "A greeting plugin to learn the basics",
  "version": "1.0.0",
  "author": {
    "name": "Your Name"
  }
}
```
For this repo: `{"name": "client-dossier", "description": "…", "version": "0.1.0"}`.
`name` is the **skill namespace**: `skills/dossier-init/` becomes `/client-dossier:dossier-init`.
`version` is optional but, once set, pins the plugin — except for a plugin loaded in place via
`--plugin-dir`, where edits take effect at the next session start or `/reload-plugins` with no
version bump. `[CITED: https://code.claude.com/docs/en/plugins]`

### Pattern 3: Marker-delimited idempotent section (D-16)

**What:** Write the protocol pointer between two HTML-comment markers; on re-run, replace the
span between markers rather than appending. Absent markers ⇒ append the whole block.
**When to use:** SCAF-05 in `AGENTS.md` (always) and `CLAUDE.md` (only if it already exists).
**Why it matters here:** D-08 (idempotence) applies to this file too. Without markers, a second
`dossier-init` run duplicates the section — the one place in this phase where "skip if the file
exists" is the *wrong* rule, because the file exists but the section may not.
`[ASSUMED]` — a conventional pattern, not sourced from a standard.

### Anti-Patterns to Avoid

- **Putting `skills/`, `agents/` or `hooks/` inside `.claude-plugin/`.** The Claude Code docs
  call this out explicitly as the common mistake: *"Don't put `commands/`, `agents/`, `skills/`,
  or `hooks/` inside the `.claude-plugin/` directory. Only `plugin.json` goes inside
  `.claude-plugin/`."* `[CITED: https://code.claude.com/docs/en/plugins]`
- **Hard-coding a relative path to `init.py` from `SKILL.md`.** The skill's working directory at
  invocation is the *user's dossier repo*, not the plugin. Always `${CLAUDE_SKILL_DIR}/…`.
- **Overwriting on re-run.** D-08 forbids it; also, on an adopted repository this would destroy
  a living dossier.
- **Interpolating counterpart names into a shell command string** (for `git mv` or otherwise).
  See *Security Domain*.
- **Translating protocol keywords.** `Last updated:`, `Status:`, `To:`, `Subject:`, `Deadline:`,
  `Written by:`, `Rules:`, `draft`, `reviewed by`, `sent` are identical in `templates/fr/`.
  Spec §3.2. This is ROADMAP success criterion 5 and Phase 2's lint fixture depends on it.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Locating the plugin's own files at runtime | Path arithmetic from `__file__`, or `git rev-parse` | `${CLAUDE_SKILL_DIR}` / `${CLAUDE_PLUGIN_ROOT}` | Documented, survives copy-vs-in-place installs and cache-directory changes. Path arithmetic breaks under a copied install. |
| Renaming folders while preserving history | `mv` + `git add`/`git rm` | `git mv` | D-15 already says `git mv`; it records the rename atomically in the index. |
| Validating the manifest shape | A hand-written JSON schema check | `claude plugin validate .` (`--strict` in CI) | Checks manifest schema, unknown fields (with typo suggestions), field types, agent frontmatter parsing and **path-traversal violations**. `[VERIFIED: claude plugin validate --help, run this session]` |
| Parsing arbitrary YAML in `init.py` | A general YAML parser | Emit a fixed template; do not parse | This phase only *writes* `dossier.yaml`. Parsing is Phase 2's problem and the spec already prescribes a tiny YAML-subset parser there. |
| Keeping empty folders in git | A placeholder `README` per leaf | `.gitkeep` | Spec §3.2 names the exact seven leaves and says the linter ignores `.gitkeep`. |

**Key insight:** Everything this phase could be tempted to hand-roll is either already solved
by a documented Claude Code path variable, or already specified verbatim in spec §3.2. The
scarce resource here is *fidelity to the spec's literal strings*, not cleverness.

## Runtime State Inventory

This phase is greenfield for `client-dossier` (spec-only repo, no code), but SCAF-06 makes it a
**migration phase for a target repository**. The inventory below is for the *adopted dossier
repo*, which is what `dossier-init` mutates.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no database, no datastore. `dossier-init` touches only the filesystem and the git index. | none |
| Live service config | None — the plugin never calls a network service (spec §1: "never sends anything"). | none |
| OS-registered state | None — no scheduler, no daemon, no launchd/systemd unit registered by init. | none |
| Secrets/env vars | None written. Init reads no secret. Note: `${CLAUDE_SKILL_DIR}`/`${CLAUDE_PLUGIN_ROOT}` are harness-provided substitutions, not user env vars — they are expanded by Claude Code before the skill body is read, so a bare `python3` invocation outside Claude Code must be given an explicit path instead. | Phase 2's bash runner must call `init.py` by absolute/relative path, not via `$CLAUDE_SKILL_DIR`. |
| Build artifacts | None — no compilation, no install step, no package. The only artifact is the created dossier tree. | none |
| **Git index of the adopted repo** (extra category, SCAF-06) | `git mv` rewrites tracked paths; untracked files under a renamed folder are *not* moved by `git mv` and will error. | `init.py`/skill must handle "path not tracked by git" — fall back to `mv` + report, or refuse and tell the user. **Open question O-2.** |

## Common Pitfalls

### Pitfall 1: A repo root with no manifest loads as a *folder of plugins*, not as one plugin
**What goes wrong:** `claude --plugin-dir .` silently loads nothing, or loads each subdirectory
as a separate plugin.
**Why it happens:** Documented behaviour (v2.1.265+): *"if the folder has no manifest or plugin
components at its top level, Claude Code treats it as a folder of plugins. Each immediate
subfolder that has a `.claude-plugin/plugin.json` manifest loads as a separate plugin. Claude
Code skips everything else in the folder without reporting an error."*
**How to avoid:** Ship `.claude-plugin/plugin.json` in Phase 1 — this is exactly SCAF-08's
justification. The failure is *silent* (no error reported), which is what makes it dangerous.
**Warning signs:** `/help` → **Custom commands** tab does not list `/client-dossier:dossier-init`.
`[CITED: https://code.claude.com/docs/en/plugins]`

### Pitfall 2: Forgetting that plugin skills are namespaced
**What goes wrong:** The spec and the ROADMAP say "running `dossier-init`". Under a plugin, the
slash command is `/client-dossier:dossier-init`, and the `name` frontmatter field sets only the
**last segment**.
**Why it happens:** Personal/project skills take their command name from the *folder*; plugin
skills take the last segment from the `name` field and get the plugin prefix automatically.
**How to avoid:** Keep folder name and `name:` identical (`dossier-init`), and write the phase's
acceptance steps as `/client-dossier:dossier-init`. Model-invoked triggering (the normal path —
skills are model-invoked on description match) is unaffected.
**Warning signs:** `/dossier-init` not found while the plugin is loaded.
`[CITED: https://code.claude.com/docs/en/skills]`

### Pitfall 3: Edits to the working copy not picked up
**What goes wrong:** You edit `SKILL.md` or `init.py` and the old version keeps running.
**Why it happens:** A `--plugin-dir` plugin is loaded **in place**, but changes apply at the
next session start or on `/reload-plugins`.
**How to avoid:** Put `/reload-plugins` in the phase's manual verification steps. No version
bump is needed for an in-place plugin.
`[CITED: https://code.claude.com/docs/en/plugins-reference]`

### Pitfall 4: The description budget is small
**What goes wrong:** A long, feature-listing `description` is truncated in the skill listing,
degrading triggering.
**Why it happens:** `description` + `when_to_use` share a **1,536 character** limit and the
listing truncates to save context. Body recommendation: under 500 lines.
**How to avoid:** Spec §4.1 already says descriptions "name the situations, not the features".
Keep `dossier-init`'s description situational and short; Phase 7 validates it with
`claude plugin eval`.
`[CITED: https://code.claude.com/docs/en/skills]`

### Pitfall 5: `.gitkeep` omitted from a leaf that *looks* non-empty at scaffold time
**What goes wrong:** A folder the scaffold leaves empty is not committed; a clone of the dossier
is missing the folder, and the next skill writes to a path that does not exist.
**Why it happens:** The "is it empty?" test is done at scaffold time; an adopted repo may have a
folder that is empty *today* (the origin repo's `communication/mails/` is exactly this case) and
therefore never survived a clone.
**How to avoid:** Follow spec §3.2 literally — write `.gitkeep` into **all seven named leaves
unconditionally**, not "if empty". It costs nothing and removes the class of bug.
**Warning signs:** `git status` after init shows fewer than seven `.gitkeep` files.

### Pitfall 6: `git mv` on untracked paths
**What goes wrong:** `git mv` fails with `fatal: not under version control` on a folder the user
created but never committed.
**Why it happens:** SCAF-06 assumes the adopted repo's folders are tracked. A freshly-created or
gitignored folder is not.
**How to avoid:** Check `git ls-files --error-unmatch <path>` before proposing the rename, and
report untracked same-role folders separately in the proposal.

### Pitfall 7: Re-running init duplicates the instructions-file section
**What goes wrong:** `AGENTS.md` grows a second copy of the protocol pointer.
**Why it happens:** D-08's "skip if the file exists" rule is wrong for `AGENTS.md`/`CLAUDE.md`,
which may exist without the section.
**How to avoid:** Marker comments (Pattern 3). This is the *only* documented exception to D-08.

## Code Examples

Verified patterns, quoted from official sources.

### The `dossier.yaml` shape (SCAF-01) — spec §3.2, verbatim
```yaml
# Source: docs/superpowers/specs/2026-09-16-client-dossier-design.md §3.2 (lines 142-157)
# dossier.yaml
version: 1
language: fr                      # language of the dossier content
counterparts:
  - name: "Acme Consulting"        # internal name, never in outbound
    role: ordering party
    contacts: [ "Jane Doe" ]
  - name: "Big Telco"
    role: end client
confidential_names: [ "Acme", "Big Telco" ]   # linter fails if found under outbound/
consent_recorded: false           # true only with consent_source filled in
consent_source: ""                # e.g. "mail 2026-09-16 from Jane"; required when true
timestamps: "@mm:ss"              # transcript citation format
date_format: "YYYY-MM-DD"
status_header: required           # outbound files must open with a status block
staleness_days: 7                 # dossier-status flags living files older than this
```
`[VERIFIED: docs/superpowers/specs/2026-09-16-client-dossier-design.md:142-157]`

### The seven `.gitkeep` leaves (SCAF-02) — spec §3.2, verbatim
> "every leaf folder the scaffold creates and leaves empty (`sources/received/`,
> `sources/transcripts/raw/`, `knowledge/decisions/`, `knowledge/watch/`,
> `outbound/deliverables/`, `outbound/mails/`, `outbound/calls/`) gets a `.gitkeep`.
> The linter ignores `.gitkeep` files."

`[VERIFIED: docs/superpowers/specs/2026-09-16-client-dossier-design.md:138-141]`

### The protocol keywords that are never translated (SCAF-07) — spec §3.2, verbatim
> "the `Last updated:` line of a living file, the field names of the status header (`Status:`,
> `To:`, `Subject:`, `Deadline:`, `Written by:`, `Rules:`) and the status values (`draft`,
> `reviewed by`, `sent`)"

`[VERIFIED: docs/superpowers/specs/2026-09-16-client-dossier-design.md:129-133]`

### The status header block for `outbound/README.md` (SCAF-04) — spec §3.3, verbatim
```
Status: draft | reviewed by <name> | sent <date time> by <name>
To: <recipient>
Subject: <subject>            (mails)
Deadline: YYYY-MM-DD          (optional: when the draft has to be sent)
Written by: <human or "agent session, YYYY-MM-DD">
Rules: no confidential names; see knowledge/DOCTRINE.md
```
`[VERIFIED: docs/superpowers/specs/2026-09-16-client-dossier-design.md:171-178]`

### The fact line (D-11 example comment) — spec §3.4, verbatim
```
- <fact, one sentence, absolute dates> (<source>, <locator>).
```
Sources given: `call @12:34`, `mail 2026-09-16 from Jane`, `brochure p. 4`, `internal note p. 15`.
`[VERIFIED: docs/superpowers/specs/2026-09-16-client-dossier-design.md:190-196]`

### Skill directory with bundled resources — open standard, verbatim
```text
# Source: https://github.com/agentskills/agentskills
my-skill/
├── SKILL.md          # Required: metadata + instructions
├── scripts/          # Optional: executable code
├── references/       # Optional: documentation
├── assets/           # Optional: templates, resources
└── ...               # Additional files/directories
```
`[CITED: https://github.com/agentskills/agentskills]`

### Plugin skill directory with scripts — Claude Code, verbatim
```text
# Source: https://code.claude.com/docs/en/plugins-reference
skills/
├── pdf-processor/
│   ├── SKILL.md
│   ├── reference.md (optional)
│   └── scripts/ (optional)
└── code-reviewer/
    └── SKILL.md
```
`[CITED: https://code.claude.com/docs/en/plugins-reference]`

### Local development loop — Claude Code, verbatim
```bash
# Source: https://code.claude.com/docs/en/plugins
claude --plugin-dir ./my-plugin
```
Repeatable for several plugins (`--plugin-dir ./plugin-one --plugin-dir ./plugin-two`), accepts a
`.zip`, and takes precedence over a same-named installed plugin for that session. Then
`/reload-plugins` to pick up edits without restarting.
`[CITED: https://code.claude.com/docs/en/plugins]`

## Origin Repository — Structural Comparison (D-13 / D-14)

Read-only structural audit of `/Users/samuel/Documents/dev/Project-POC-RELATION-CLIENT`,
performed this session. **Only folder names, file names and markdown heading text are reported;
every heading that embeds a real person or organisation name has that name redacted as
`<name>`. No file body was read or quoted.**

### Actual top-level layout

```
.gitignore   CLAUDE.md   README.md
client/      ACTEURS.md APPRENTISSAGES.md CANAUX.md HISTORIQUE.md
             QUESTIONS-OUVERTES.md RELATION.md TON.md README.md
communication/  README.md  appels/  livrables/  mails/
docs/        CONTEXTE.md  DOCTRINE.md  decisions/  veille/README.md
pipeline/    DESIGN.md README.md assets/{fonts,img} bin/ templates/
sources/     internes/  plaquette/  transcripts/  transcripts/raw/
```

### D-14 mapping — verdict per row

| D-14 claim | Reality on disk | Verdict |
|---|---|---|
| `client/` → `dossier/` | `client/` exists with exactly the seven living files + `README.md` | ✅ confirmed |
| seven `client/*.md` → seven English names | `ACTEURS`, `APPRENTISSAGES`, `CANAUX`, `HISTORIQUE`, `QUESTIONS-OUVERTES`, `RELATION`, `TON` — all seven, no extras | ✅ confirmed |
| `communication/{appels,livrables,mails}` → `outbound/{calls,deliverables,mails}` | all three exist | ✅ confirmed |
| `docs/{CONTEXTE.md,DOCTRINE.md,decisions,veille}` → `knowledge/{CONTEXT.md,DOCTRINE.md,decisions,watch}` | all four exist | ✅ confirmed |
| `pipeline/` left untouched and reported ignored (D-17) | `pipeline/` exists with `bin/`, `templates/`, `assets/` | ✅ confirmed |
| `sources/` already correctly named | `sources/` exists; `sources/transcripts/` and `sources/transcripts/raw/` match spec §3.2 **exactly** | ✅ confirmed |

### Discrepancies to flag

**DISC-1 — `sources/internes/` and `sources/plaquette/` are unmapped (affects SCAF-06 acceptance).**
The origin's `sources/` has four children: `internes/`, `plaquette/`, `transcripts/`,
`transcripts/raw/`. Spec §3.2 prescribes `received/` and `transcripts/ (+ raw/)`. D-14's rename
table lists `transcripts` and `raw` but says nothing about `internes` or `plaquette`; D-13 and the
Deferred Ideas both say "the spec layout stands". Consequence as currently decided: running init on
a copy of the origin repo creates an **empty `sources/received/`** while leaving two populated
source folders behind as "ignored" (D-17) — which contradicts CONTEXT's stated acceptance case
that init "must propose exactly the mapping of D-14 and leave `pipeline/` alone". `pipeline/` is
deliberately ignored; `sources/internes/` is not obviously so. **Planner decision needed** — either
(a) add `internes|internal|plaquette|brochure|recu|received → sources/received/` to the D-14 table,
or (b) state explicitly that source *sub*folders are never renamed and the report says so. This is
the only discrepancy with acceptance-criteria impact.

**DISC-2 — `docs/veille/README.md` maps to `knowledge/watch/README.md`, which SCAF-04 does not create.**
SCAF-04 lists exactly three READMEs (`dossier/`, `sources/`, `outbound/`). The origin has a README
inside `docs/veille/`, and `knowledge/` itself has no README. Two consequences: (i) `knowledge/watch/`
is a `.gitkeep` leaf per spec §3.2, but after a rename it would contain a README — the script must
not choke on a "leaf" that is non-empty; (ii) no new template is needed — the renamed file simply
rides along. **No spec change recommended**; just do not assume `knowledge/watch/` is empty.

**DISC-3 — three living-file templates need generic headings where the origin has per-exchange or
per-party ones.** Structure-only findings:
- `TON.md` has *two* per-exchange sections (`## Ce que l'appel ajoute`, `## Ce que le débrief impose`)
  where spec §2.2 has one ("what each exchange added"). The template should ship **one** generic
  section (e.g. `## Ce que les échanges ajoutent`) that grows by bullet, not by heading.
- `QUESTIONS-OUVERTES.md`'s first section is dated (`## Réponses obtenues le <date>`, written
  `16/09`, not ISO). The template must use an undated generic heading, and any date the agent
  later writes must be `YYYY-MM-DD` (spec §2.3).
- `RELATION.md` and `APPRENTISSAGES.md` have party-named headings (`## Vu de <name>`,
  `## Vu d'<name>, tel qu'on peut le reconstituer`, `## Comment <name> parle et pense`). The
  templates must use role-generic labels ("notre point de vue" / "leur point de vue, reconstitué" /
  "comment ils parlent et pensent"), since counterpart names are not known until scaffold time —
  and, for `outbound/`, are confidential.

**DISC-4 — `HISTORIQUE.md` does not split "commitments in progress" into ours/theirs at heading level.**
Spec §2.2 and D-10 both say "commitments in progress (ours, theirs)". The origin has a single
`## Engagements en cours`. The ours/theirs distinction evidently lives inside the section, not as
sub-headings. **Recommendation:** follow spec §2.2 (two sub-headings or two labelled lists) since
it is the source of truth, but note the origin does not do this — a low-risk divergence.

### Heading audit — spec §2.2 vs reality (structure only, names redacted)

| Living file | Origin headings (`##`, names redacted) | Spec §2.2 section list | Match |
|---|---|---|---|
| `ACTEURS.md` → `ACTORS.md` | Côté donneur d'ordre / Le client final / Côté \<us\> (with `###` per person) | "Grouped by side (ordering party, end client, us)" | ✅ exact, three groups, `###` = person |
| `HISTORIQUE.md` → `HISTORY.md` | Avant le \<date\> / \<date\> / Engagements en cours / À venir | chronology + commitments in progress (ours, theirs) + upcoming | ⚠️ see DISC-4 |
| `APPRENTISSAGES.md` → `LEARNINGS.md` | Comment \<name\> parle et pense / Ce qu'il attend d'un document / Ce que le dossier apprend / Pièges connus | how they speak and think / what they expect of a document / what the case teaches / known pitfalls | ✅ exact, 4 sections, same order (see DISC-3 for the name) |
| `TON.md` → `TONE.md` | En une phrase / Ce qui est établi (…) / Ce que l'appel ajoute / Ce que le débrief impose / Structure d'un document pour \<name\> / Structure d'un message court (mail, WhatsApp) / Refusé | voice in one sentence / what is established / what each exchange added / structure of a long document / structure of a short message / Refused log | ⚠️ see DISC-3 |
| `CANAUX.md` → `CHANNELS.md` | Visioconférence et enregistrement / Documents / Mail / Appels / Ce dépôt | video and recording etiquette / documents / mail addresses / call habits / the repository and its confidentiality level | ✅ exact, 5 sections, same order |
| `QUESTIONS-OUVERTES.md` → `OPEN-QUESTIONS.md` | Réponses obtenues le \<date\> / Toujours ouvertes côté \<name\> / Ce qu'on poserait au client final | three tables: answered / still open on the counterpart side / what we would ask the end client | ⚠️ see DISC-3 |
| `RELATION.md` → `RELATIONSHIP.md` | État en une ligne / Chiffres de la relation / Vu de \<name\> / Vu d'\<name\>, tel qu'on peut le reconstituer / Améliorations concrètes / Ventes possibles, par ordre de probabilité / Points à garder en tête | one-line status / metrics table / our view / their view as we reconstruct it / concrete improvements / sales opportunities ranked by probability / points to keep in mind | ✅ exact, 7 sections, same order (see DISC-3 for names) |

**`knowledge/` stubs (D-12), structure only:**
- `docs/CONTEXTE.md` → `## L'objet` / `## Ce qui est demandé maintenant` / `## Ce que le client
  final a déjà` / `## Ce que \<us\> apporte, dans les mots de la note interne` / `## Ce que le
  débrief a ajouté` / `## Les documents sources`. Spec prescribes no sections for `CONTEXT.md`, so
  this is the only structural evidence available. Recommended generic template sections: l'objet /
  ce qui est demandé maintenant / ce que le client a déjà / ce que nous apportons / les documents
  sources — the per-exchange ones ("ce que le débrief a ajouté") are engagement-specific and should
  not be templated.
- `docs/DOCTRINE.md` → nine `##` headings, of which the **last three** are
  `## Ce qu'on dit` / `## Ce qu'on ne dit pas` / `## Le vocabulaire, en une phrase chacun`.
  These map one-to-one onto SCAF-04's "two lists" + D-12's vocabulary section. **D-12 is confirmed
  against reality.** The other six headings are engagement-specific doctrine *content* and are
  correctly excluded from the template.

**Other structural facts worth carrying forward:**
- `communication/mails/` is **empty** and has no `.gitkeep` — direct evidence for SCAF-02's rule.
- `communication/livrables/` holds a `.html` and a `.pdf` with the same stem — matches the future
  lint rule "rendered deliverables have their source file next to them" (LINT-01).
- Source and outbound files already use `YYYY-MM-DD_slug` (and one `YYYY-MM_slug`) — matches the
  spec's naming rule; the `YYYY-MM` one would fail LINT-01's outbound filename check but is under
  `sources/`, which that rule does not cover.
- The origin has **no** `dossier.yaml`, **no** `.gitkeep` anywhere, **no** `AGENTS.md`, and a
  top-level `CLAUDE.md` — so D-16's "AGENTS.md always, CLAUDE.md only if present" produces exactly
  one new file and one edited file on this repo.

`[VERIFIED: /Users/samuel/Documents/dev/Project-POC-RELATION-CLIENT — `find` + `grep -n '^#\{1,4\} '`, run this session]`

## Project Constraints (from CLAUDE.md)

Extracted from `/Users/samuel/Documents/dev/client-dossier/CLAUDE.md`. Treat with the same
authority as CONTEXT.md's locked decisions.

| # | Directive | Impact on this phase |
|---|---|---|
| C-1 | The spec is the single source of truth; when CLAUDE.md and the spec disagree, the spec wins and CLAUDE.md must be updated. | D-06 amends spec §4 → the spec edit *and* the CLAUDE.md edit are both phase deliverables. |
| C-2 | The plugin (skills, agents, scripts, docs, commit messages) is written in **English**. Dossier *content* is in the `dossier.yaml` language. | `SKILL.md`, `init.py`, commit messages in English; `templates/fr/` content in French. |
| C-3 | Folder and file names are **fixed English, never configurable**; no name mapping table. | The D-14 rename table is one-way, used only at adoption time — not a runtime mapping. |
| C-4 | Protocol keywords are English and never translated; the linter greps them; no per-language label table. | ROADMAP criterion 5; `templates/fr/` keeps them byte-identical to `templates/en/`. |
| C-5 | **Scripts carry mechanics**: anything a regex can check belongs in a script, not in skill prose. | D-05 split. |
| C-6 | `scripts/lint.py` is **Python 3 standard library only**. | Extends to `init.py` by the same rule (D-05 and CONTEXT Discretion both restate it). |
| C-7 | Skills must contain the inline procedure for harnesses without the machinery. | D-07's inline fallback is mandatory, not optional. |
| C-8 | External dependencies have a stated fallback. | `git` absent → `git mv` must degrade to a reported failure, not a crash. |
| C-9 | Tests: fixture repositories + a bash runner; **no test framework beyond bash and python3**. | Phase 1's smoke test is bash. |
| C-10 | A **minimal** `.claude-plugin/plugin.json` exists from Phase 1 for `claude --plugin-dir .`. | SCAF-08, confirmed by research. |
| C-11 | Sources are immutable; corrections go in the living files. | `init.py` must never write under `sources/` except `.gitkeep` at scaffold time. |
| C-12 | The Stop-hook v1 question is decided in Phase 3 **with Samuel**; do not settle unilaterally. | Out of scope here; do not pre-empt in the `AGENTS.md` pointer text. |

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `commands/` flat `.md` files for plugin commands | `skills/<name>/SKILL.md` directories | Current docs: *"Commands: Skills as flat Markdown files. **Use `skills/` for new plugins**"* | Spec §4's `commands/` folder (Phase 7) is the legacy shape; the planner should note that Phase 7 may not need it at all, since plugin skills are already invocable as `/client-dossier:<name>`. `[CITED: https://code.claude.com/docs/en/plugins]` |
| Manifest strictly required | Manifest optional; auto-discovery of `skills/`, `commands/`, `agents/`, `hooks/hooks.json`, `.mcp.json`, `.lsp.json` | Current docs | SCAF-08 is still the right call (see Pitfall 1), but it is a *disambiguation*, not a hard requirement. |
| Hard-coded relative paths in skills | `${CLAUDE_SKILL_DIR}`, `${CLAUDE_PLUGIN_ROOT}`, `${CLAUDE_PROJECT_DIR}`, `${CLAUDE_PLUGIN_DATA}` | `${CLAUDE_PROJECT_DIR}` in skills requires v2.1.196+; `--plugin-dir` on a folder-of-plugins requires v2.1.265+ | Local CLI is 2.1.273 — above both thresholds. `[VERIFIED: claude --version, run this session]` |

**Deprecated/outdated:** nothing in this phase's stack is deprecated. `commands/` is legacy-but-supported.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The marker-comment idempotence pattern for `AGENTS.md`/`CLAUDE.md` (D-16, Pattern 3) is a convention, not something any standard specifies. | Architecture Patterns / Pitfall 7 | None — it is a locked user decision (D-16); listed only for honesty about provenance. |
| A2 | `init.py` should target Python ≥3.8 for portability. Only 3.14.6 was observed locally; no minimum is declared anywhere in the spec or CLAUDE.md. | Standard Stack | If a contributor's machine has an older `python3`, an f-string or `pathlib` feature could fail. Cheap mitigation: avoid 3.9+-only syntax, or declare the minimum in CLAUDE.md. **Worth a planner decision.** |
| A3 | The origin repo's `## Engagements en cours` splits ours/theirs inside the section body rather than as sub-headings. Inferred from the absence of sub-headings; the body was deliberately **not** read (confidential). | DISC-4 | Low — the spec is the source of truth for the template either way. |
| A4 | `${CLAUDE_SKILL_DIR}` is not expanded when `init.py` is invoked directly from bash (Phase 2 runner). Inferred from it being a harness-side substitution performed before the skill body is read. | Runtime State Inventory | Low, and self-correcting: the Phase 2 runner would fail loudly on an unexpanded literal. |
| A5 | No security control beyond input sanitisation is needed, since the plugin makes no network calls (spec §1) and stores no secret. | Security Domain | Low. |

## Open Questions

1. **O-1 — `templates/` vs `assets/` inside the skill folder.**
   - What we know: the Agent Skills open standard names the static-resource folder `assets/`;
     `templates/` is legal as an "additional directory" and Claude Code documents no restriction.
   - What's unclear: whether any harness in the "bare-skills" row of spec §8 (Codex, Cursor,
     Gemini CLI, OpenCode) special-cases `assets/`. No evidence found either way.
   - Recommendation: **keep `templates/` (D-06 is locked and more self-describing)**. Revisit only
     if a harness is observed to ignore non-canonical subfolders. Low risk — bare-skills installers
     copy/symlink the whole folder.

2. **O-2 — `git mv` on untracked same-role folders (SCAF-06).**
   - What we know: D-15 says the skill executes `git mv` after confirmation. `git mv` fails on
     untracked paths.
   - What's unclear: whether to fall back to plain `mv`, or refuse and tell the user to commit first.
   - Recommendation: **check `git ls-files --error-unmatch` per candidate and report untracked
     folders in a separate line of the proposal** ("not tracked by git — will be moved with `mv`,
     history not preserved"), letting the user decide. Needs a one-line planner decision.

3. **O-3 — DISC-1: does `sources/internes/`/`plaquette/` get mapped to `sources/received/`?**
   - What we know: D-14's table omits them; D-13 and Deferred Ideas say the spec layout stands;
     CONTEXT's Specific Ideas say the origin repo is the SCAF-06 acceptance case and init "must
     propose exactly the mapping of D-14".
   - What's unclear: whether "ignored" (D-17) is the intended outcome for populated source
     subfolders, or an oversight.
   - Recommendation: **ask Samuel during planning.** Cheapest resolution that preserves both
     decisions: keep the spec layout, do not rename source subfolders, but make the report say
     explicitly "`sources/internes/`, `sources/plaquette/`: left in place — the spec's
     `sources/received/` was created empty; move these yourself if you want them there."

4. **O-4 — Does the spec-§4 amendment (D-06) land in this phase's commits?**
   - What we know: D-06 says the tree "is to be amended accordingly during this phase"; CLAUDE.md
     C-1 says the spec wins and CLAUDE.md must be updated.
   - Recommendation: make the spec §4 edit and the CLAUDE.md edit **explicit tasks** in the plan,
     not incidental, and verify no other spec section still says `templates/` at root.

5. **O-5 — Minimum Python version (A2).** Recommendation: declare `python3 ≥ 3.8` in CLAUDE.md
   when the first script lands, and keep `init.py` inside that subset.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `python3` | `init.py` (D-05) | ✓ | 3.14.6 | Skill inline procedure (D-07) |
| `git` | `git mv` renames (SCAF-06/D-15) | ✓ | 2.50.1 (Apple Git-155) | Report and skip renames (C-8) |
| `claude` CLI | `--plugin-dir .` acceptance (SCAF-08) | ✓ | 2.1.273 | — |
| `claude plugin validate` | manifest verification | ✓ | subcommand present, supports `--json` and `--strict` | Manual JSON review |
| `bash` | Phase 2 test runner | ✓ | system | — |
| `node` | not required by this phase | ✓ | v26.5.0 | — |
| `pdftotext` | **Phase 4 only**, not this phase | ✓ | /opt/homebrew/bin/pdftotext | Spec §6 fallback already defined |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** none — every dependency this phase needs is present.

`[VERIFIED: command -v / --version probes run this session]`

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | **none yet** — bash + `python3` only, mandated by `CLAUDE.md` ("No test framework beyond bash and python3") |
| Config file | none — see Wave 0 |
| Quick run command | `bash tests/run.sh` (to be created) |
| Full suite command | `bash tests/run.sh` (same; the suite is small by design) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SCAF-01 | `dossier.yaml` written with all ten keys | unit (bash+grep) | `bash tests/test-init-empty.sh` → asserts each of `version:`, `language:`, `counterparts:`, `confidential_names:`, `consent_recorded:`, `consent_source:`, `timestamps:`, `date_format:`, `status_header:`, `staleness_days:` present | ❌ Wave 0 |
| SCAF-02 | 4 folders + subfolders + 7 `.gitkeep` | unit | same script → `test -f` on each of the seven leaves named in spec §3.2 | ❌ Wave 0 |
| SCAF-03 | 7 living files, each with `Last updated:` + "Updated when" comment | unit | same script → `grep -q '^Last updated:'` on each of the seven English filenames | ❌ Wave 0 |
| SCAF-04 | `knowledge/CONTEXT.md`, `knowledge/DOCTRINE.md` (two lists), 3 READMEs | unit | same script → `test -f` ×5, plus `grep -q` for the two DOCTRINE list headings | ❌ Wave 0 |
| SCAF-05 | Protocol section in `AGENTS.md`; also `CLAUDE.md` if present | unit | `bash tests/test-init-pointer.sh` → run twice, assert exactly one marker pair in each file (covers D-08 + Pitfall 7) | ❌ Wave 0 |
| SCAF-06 | Rename proposal on a fixture with FR folder names | integration | `bash tests/test-init-adopt.sh` → build a throwaway git repo mirroring the origin's *names only*, run init in propose-only mode, diff the proposal against a golden file | ❌ Wave 0 |
| SCAF-07 | `language: fr` → French headings, English protocol keywords | unit | `bash tests/test-init-fr.sh` → `grep -q 'Last updated:'` **and** `grep -q` a known French heading; `grep -qv` any translated keyword | ❌ Wave 0 |
| SCAF-08 | Manifest valid, plugin loads | smoke | `claude plugin validate . --strict` (exit 0) | ❌ Wave 0 |
| D-08 | Idempotence: second run creates nothing new | unit | run init twice into the same dir, `diff -r` the two snapshots → empty | ❌ Wave 0 |
| Criterion 1 (ROADMAP) | End-to-end load + run in a real session | manual | `claude --plugin-dir .` then `/client-dossier:dossier-init` in a scratch repo | manual-only — requires an interactive Claude Code session; no headless equivalent |

### Sampling Rate
- **Per task commit:** `bash tests/run.sh` (target < 5 s; it is filesystem + grep only)
- **Per wave merge:** `bash tests/run.sh && claude plugin validate . --strict`
- **Phase gate:** full suite green **plus** the one manual interactive check before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `tests/run.sh` — the bash runner (dispatches every `tests/test-*.sh`, sums exit codes)
- [ ] `tests/lib.sh` — shared assert helpers (`assert_file`, `assert_grep`, `mktemp -d` scratch repo)
- [ ] `tests/test-init-empty.sh` — covers SCAF-01, SCAF-02, SCAF-03, SCAF-04
- [ ] `tests/test-init-fr.sh` — covers SCAF-07 (ROADMAP criterion 5)
- [ ] `tests/test-init-pointer.sh` — covers SCAF-05 + D-08/Pitfall 7
- [ ] `tests/test-init-adopt.sh` + a names-only fixture repo — covers SCAF-06 (ROADMAP criterion 4)
- [ ] Framework install: **none** — bash and `python3` are already present

> Fixture note: the SCAF-06 fixture must be built from **folder and file names only** (this
> research document's structural audit is sufficient input). It must never contain a copy of the
> origin repository's file contents.

## Security Domain

`security_enforcement: true`, `security_asvs_level: 1` (`.planning/config.json`). This phase is a
local scaffolding script; there is no server, no auth, no network, no session.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No identity, no credential, no login surface. |
| V3 Session Management | no | No session. |
| V4 Access Control | no | Single local user; the only "authorisation" is the human confirmation gate before `git mv` (D-15), which is a UX control, not an ASVS one. |
| V5 Input Validation | **yes** | Counterpart names, roles, contacts and language come from free-form user input and are written into `dossier.yaml`, into file bodies, and used to build paths. Validate and quote. |
| V6 Cryptography | no | Nothing encrypted, hashed or signed in this phase. (Phase 4's "same hash" source dedup is a non-security integrity check.) |
| V12 File & Resource (L1) | **yes** | The script writes a tree and moves folders. Confine every write under the target dossier root; never follow `..`. |
| V13 API/Web Service | no | No API. |

### Known Threat Patterns for a Python scaffolding script + `git mv`

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Path traversal via a counterpart name or slug used in a path | Tampering | Never derive a path component from user input in this phase (all paths are fixed English constants, spec §3.2 / C-3). If any future slug is derived, whitelist `[A-Za-z0-9._-]` and `Path.resolve().is_relative_to(root)`. |
| Command injection via `git mv` with an interpolated folder name | Tampering / EoP | Use `subprocess.run([...], shell=False)` with an argument **list**; never build a shell string. Never `os.system`. Prefix user-supplied paths with `--` where the command supports it. |
| YAML injection into `dossier.yaml` (a name containing `"`, `:`, a newline, or `#`) breaking the file or smuggling a key | Tampering | Quote every scalar and escape `"` and `\`; reject or strip control characters and newlines from names before writing. Phase 2's `lint.py` parses this file — a malformed `dossier.yaml` breaks the linter for every later phase. |
| Overwriting a living dossier on re-run | Destruction / Tampering | D-08: existence check before every write; never truncate. This is the single highest-impact control in the phase. |
| Writing under `sources/` (immutability invariant) | Tampering | `init.py` writes only `.gitkeep` under `sources/*`; the Phase 3 PreToolUse hook enforces the rest. |
| Symlink in an adopted repo pointing outside the dossier | Tampering | `os.path.realpath` each candidate before renaming; skip and report anything resolving outside the repo root. |
| Confidential name leaking into `outbound/` at scaffold time | Info disclosure | Templates and READMEs are generic; **no counterpart name may be interpolated into anything under `outbound/`** (spec §3.2, LINT-01). The D-11 example lines use the spec's fictional "Jane Doe (Acme)". |
| Plugin path traversal in the manifest | Tampering | `claude plugin validate` checks path-traversal violations; all manifest paths must start with `./`. `[CITED: https://code.claude.com/docs/en/plugins-reference]` |

## Sources

### Primary (HIGH confidence)
- `docs/superpowers/specs/2026-09-16-client-dossier-design.md` — §2.2, §2.3, §3.2, §3.3, §3.4, §4,
  §4.1, §4.5, §6, §8 read verbatim this session
- `/Users/samuel/Documents/dev/client-dossier/CLAUDE.md`, `.planning/REQUIREMENTS.md`,
  `.planning/ROADMAP.md`, `.planning/config.json`, `.planning/phases/01-scaffold-templates/01-CONTEXT.md`
- `/Users/samuel/Documents/dev/Project-POC-RELATION-CLIENT` — `find` + heading `grep`, structure only
- Local environment probes: `claude --version` (2.1.273), `python3 --version` (3.14.6),
  `git --version` (2.50.1), `claude plugin validate --help`

### Secondary (MEDIUM confidence)
- https://code.claude.com/docs/en/plugins — plugin quickstart, manifest fields, `--plugin-dir`,
  `/reload-plugins`, `.claude-plugin/` warning, folder-of-plugins behaviour, `claude plugin validate`
- https://code.claude.com/docs/en/plugins-reference — full manifest schema, path variables,
  in-place loading, validation semantics, plugin skill directory with `scripts/`
- https://code.claude.com/docs/en/skills — SKILL.md frontmatter table, `${CLAUDE_SKILL_DIR}`,
  bundled `scripts/` + `assets/`, 1,536-char description limit, 500-line body guidance, namespacing
- https://github.com/agentskills/agentskills — the Agent Skills open standard: skill folder layout
  with `scripts/`, `references/`, `assets/` and "additional files/directories"
- Context7 `/websites/code_claude` — cross-check of the plugin skill directory layout and
  `${CLAUDE_SKILL_DIR}` snippet against the same two Claude Code pages

### Tertiary (LOW confidence)
- https://github.com/vercel-labs/skills and https://www.npmjs.com/package/skills — the `npx skills`
  CLI copies or symlinks the *whole* skill folder into `.agents/skills/` (and `.claude/skills/` when
  Claude Code is detected). Used only to support the "bundled resources survive a bare-skills
  install" claim; relevant to Phase 7, not to this phase's deliverables.

## Metadata

**Confidence breakdown:**
- Bundled-resource layout (D-06): **HIGH** — two independent official sources (Anthropic docs +
  the Agent Skills open standard) both document `scripts/` inside a skill folder; Claude Code
  additionally provides `${CLAUDE_SKILL_DIR}` specifically to address it.
- Plugin manifest & `--plugin-dir` (SCAF-08): **HIGH** — quickstart, reference schema and the
  locally installed CLI (`claude plugin validate --help`) agree.
- Origin-repo structural comparison: **HIGH** — read from disk this session; every claim is a
  filename or a `#` heading, both directly observable.
- Template section lists (DISC-3/DISC-4 recommendations): **MEDIUM** — derived from heading
  structure only; the file bodies were deliberately not read, so the ours/theirs inference (A3) is
  unconfirmed.
- Standard stack: **HIGH** — no external dependency; every tool verified present with its version.
- Pitfalls: **HIGH** for 1–4 (documented behaviour), **MEDIUM** for 5–7 (reasoned from the spec
  and the origin repo's observed state).
- `templates/` vs `assets/` (O-1): **LOW** on harness behaviour — no evidence found either way.

**Research date:** 2026-09-16
**Valid until:** 2026-10-16 for the spec/origin findings (stable). **2026-09-23 for the Claude Code
plugin and skills findings** — the CLI moves fast (folder-of-plugins landed in 2.1.265, local is
2.1.273); re-check the two doc pages if planning slips more than a week.
