# Phase 1: Scaffold & Templates - Context

**Gathered:** 2026-09-16
**Status:** Ready for planning

<domain>
## Phase Boundary

The `dossier-init` skill, its templates and a minimal `.claude-plugin/plugin.json` turn any
repository (empty or pre-existing) into a correctly laid-out dossier in one step: `dossier.yaml`,
the four top-level folders with their subfolders (`.gitkeep` in every empty leaf), the seven
living files, `knowledge/CONTEXT.md`, `knowledge/DOCTRINE.md`, one README per top-level folder
(`dossier/`, `sources/`, `outbound/`), a protocol pointer in the instructions file, and, on an
existing repository, `git mv` renames to the fixed English names. The plugin loads from the
working copy with `claude --plugin-dir .`.

Not in this phase: the linter (Phase 2), the protocol skill and hooks (Phase 3), any other
skill, the commands folder and the full manifests (Phase 7).

</domain>

<decisions>
## Implementation Decisions

### Input collection (what `dossier-init` asks)
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

### Scaffold mechanics (script vs prose)
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

### Templates (content and language)
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

### Adopting an existing repository (SCAF-06)
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

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Design spec (source of truth)
- `docs/superpowers/specs/2026-09-16-client-dossier-design.md` — the whole design; for this
  phase especially §2.2 (the seven files), §3.2 (layout, `dossier.yaml`, protocol keywords,
  `.gitkeep`), §3.3 (status header, for the outbound README), §4 (architecture tree, to amend
  per D-06), §4.1 `dossier-init`, §4.5 templates, §6 (nearest `dossier.yaml`), §11 (settled
  decisions).
- `CLAUDE.md` — repository instructions kept in step with the spec; invariants list.

### Planning
- `.planning/REQUIREMENTS.md` — SCAF-01 … SCAF-08 (this phase), LINT-01/02 (what Phase 2 will
  check against the output of this phase).
- `.planning/ROADMAP.md` — Phase 1 goal and the five success criteria.
- `.planning/PROJECT.md` — Key Decisions table (settled 2026-09-16) and constraints.

### Origin repository (structure only, content confidential)
- `/Users/samuel/Documents/dev/Project-POC-RELATION-CLIENT` — the live engagement repository
  the method comes from. Read folder and file names and the headings of `client/*.md`,
  `docs/CONTEXTE.md`, `docs/DOCTRINE.md`, `communication/README.md`, `client/README.md`.
  **Never copy, quote or reuse its content**; it names real people and organisations.

### External standards
- Agent Skills standard (`SKILL.md` frontmatter, bundled `scripts/` and resources inside a
  skill folder) — check the current spec at implementation time for the exact allowed layout.
- Claude Code plugin manifest (`.claude-plugin/plugin.json` minimal fields) and
  `claude --plugin-dir <path>` — verify against current Claude Code docs.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- None in this repository (spec-only). The origin repository provides the reference structure
  for the French templates and the rename mapping (D-13, D-14), structure only.

### Established Patterns
- Spec principle "skills carry the judgement, scripts carry the mechanics, hooks carry the
  reminders" — D-05 applies it to init.
- Fixed English names and protocol keywords everywhere; no name mapping table in any
  component (only the one-way rename table of D-14, used at adoption time).
- Python 3 standard library only for scripts; bash + python3 only for tests.

### Integration Points
- Phase 2 (`lint.py`, fixtures): the clean fixture is what `dossier-init` produces; the bash
  runner may call `init.py` to build it. Keep `init.py` callable non-interactively with all
  inputs as arguments.
- Phase 3 (`dossier` protocol skill): will describe the layout that init creates; the
  instructions-file section written by init (D-16) is the no-plugin fallback of spec §8.
- Phase 7: completes `.claude-plugin/plugin.json` started here (SCAF-08) and adds the commands.

</code_context>

<specifics>
## Specific Ideas

- The user's own dossiers are in French: the `fr/` template variant is the one that must be
  right first; `en/` is the source for other languages.
- The origin repository is the acceptance case for SCAF-06: running `dossier-init` on a copy
  of it must propose exactly the mapping of D-14 and leave `pipeline/` alone.
- Example lines and guiding questions live in HTML comments so a freshly scaffolded dossier
  lints clean (no warnings) and contains no fake facts.

</specifics>

<deferred>
## Deferred Ideas

- `pipeline/` of the origin repository (HTML → PDF rendering with fonts and design file):
  out of v1 scope per spec §9 D and §10; a later rendering plugin could hook into
  `outbound/deliverables/`.
- Whether `sources/` should get role subfolders beyond `received/` and `transcripts/`
  (the origin uses `internes/` and `plaquette/`): not changed in this phase; the spec layout
  stands. Revisit if ingest (Phase 4) needs it.

</deferred>

---

*Phase: 01-scaffold-templates*
*Context gathered: 2026-09-16*
