# Phase 1: Scaffold & Templates - Pattern Map

**Mapped:** 2026-09-16
**Files analyzed:** 32 to create (1 manifest, 1 SKILL.md, 1 script, 24 templates, 5 test files) + 2 to modify
**Analogs found:** 0 in-repo / 32 — **this repository is greenfield**

---

## Greenfield Declaration (read this first)

`client-dossier` contains **no source code**. Verified this session:

```
$ git ls-files
.gitignore
.planning/…            (10 planning docs)
CLAUDE.md
docs/superpowers/specs/2026-09-16-client-dossier-design.md
```

Eighteen tracked files, all Markdown/JSON planning or specification. There is **no `skills/`, no
`scripts/`, no `tests/`, no `.claude-plugin/`, no Python, no shell script**. Phase 1 writes the
first executable artefact this repository has ever had.

**Consequence for the planner:** there is no in-repo analog to copy from, and none is invented
below. What replaces "closest analog" here is a different, weaker but honest kind of pattern:

| Substitute source | What it authorises | Strength |
|---|---|---|
| **Spec verbatim blocks** (`docs/superpowers/specs/2026-09-16-client-dossier-design.md`) | Literal strings that must appear byte-for-byte in the output (`dossier.yaml` keys, `.gitkeep` leaves, protocol keywords, status header, fact line) | **Binding** — source of truth per CLAUDE.md C-1 |
| **01-RESEARCH.md "Recommended Project Structure"** (lines 275-299) | The exact tree this phase creates | **Binding** — locked by D-06 |
| **Origin repo structural audit** (01-RESEARCH.md lines 564-673) | Heading names and section order for the FR templates | **Strong** — read from disk, structure only, content confidential |
| **Sibling-ecosystem plugins** (three found, §Cross-Repo Conventions) | Frontmatter shape, bundled-resource layout, manifest field shape | **Weak, advisory** — other repos, other authors, not this project's conventions |

Do not treat the sibling-ecosystem findings as authoritative. They confirm that the shapes
RESEARCH.md derived from the docs are the shapes actually used on this machine; they decide nothing.

---

## File Classification

The "role" column uses the spec's own tiering (§4: *skills carry the judgement, scripts carry the
mechanics, hooks carry the reminders*), not web tiers.

| File to create | Role | Data Flow | Closest analog | Match quality |
|---|---|---|---|---|
| `.claude-plugin/plugin.json` | config / manifest | static declaration, read once at harness load | *(none in-repo)* — shape from spec §4 + RESEARCH Pattern 2 | no analog; canonical shape known |
| `skills/dossier-init/SKILL.md` | skill (judgement tier) | request-response: user sentence → one grouped question → script invocation → report | *(none in-repo)* — frontmatter convention cross-checked against 3 sibling skills | no analog; convention confirmed |
| `skills/dossier-init/scripts/init.py` | script (mechanics tier), CLI utility | file-I/O + batch; idempotent create-if-missing over a fixed path set | *(none in-repo)* — behaviour fully specified by spec §3.2 + D-08 | no analog; behaviour fully specified |
| `skills/dossier-init/templates/en/ACTORS.md` | template / static asset | transform (copy, or copy+translate) | origin `client/ACTEURS.md` headings (structure only) | structural, exact (3 groups) |
| `skills/dossier-init/templates/en/HISTORY.md` | template | transform | origin `client/HISTORIQUE.md` headings | structural, ⚠ DISC-4 |
| `skills/dossier-init/templates/en/LEARNINGS.md` | template | transform | origin `client/APPRENTISSAGES.md` headings | structural, exact (4 sections) |
| `skills/dossier-init/templates/en/TONE.md` | template | transform | origin `client/TON.md` headings | structural, ⚠ DISC-3 |
| `skills/dossier-init/templates/en/CHANNELS.md` | template | transform | origin `client/CANAUX.md` headings | structural, exact (5 sections) |
| `skills/dossier-init/templates/en/OPEN-QUESTIONS.md` | template | transform | origin `client/QUESTIONS-OUVERTES.md` headings | structural, ⚠ DISC-3 |
| `skills/dossier-init/templates/en/RELATIONSHIP.md` | template | transform | origin `client/RELATION.md` headings | structural, exact (7 sections), ⚠ DISC-3 names |
| `skills/dossier-init/templates/en/CONTEXT.md` | template (knowledge stub) | transform | origin `docs/CONTEXTE.md` headings | structural, partial (spec prescribes no sections) |
| `skills/dossier-init/templates/en/DOCTRINE.md` | template (knowledge stub) | transform | origin `docs/DOCTRINE.md` last 3 headings | structural, exact on the 3 that matter |
| `skills/dossier-init/templates/en/README-dossier.md` | template (README) | static | origin `client/README.md` (H1 title only, no `##`) | structural, thin |
| `skills/dossier-init/templates/en/README-sources.md` | template (README) | static | **none** — origin has no `sources/README.md` | **no analog, net-new** |
| `skills/dossier-init/templates/en/README-outbound.md` | template (README) | static | origin `communication/README.md` (H1 only) + spec §3.3 status-header block | structural + spec-verbatim |
| `skills/dossier-init/templates/fr/*.md` (same 12 names) | template | transform | the origin's **actual French headings** (audit table) | **best analog in the whole phase** |
| `tests/run.sh` | test (dispatcher) | batch | *(none in-repo)* | no analog |
| `tests/lib.sh` | test (assert helpers) | batch | *(none in-repo)* | no analog |
| `tests/test-init-empty.sh` | test | batch, filesystem assertions | *(none in-repo)* | no analog |
| `tests/test-init-fr.sh` | test | batch | *(none in-repo)* | no analog |
| `tests/test-init-pointer.sh` | test | batch, run-twice idempotence | *(none in-repo)* | no analog |
| `tests/test-init-adopt.sh` + names-only fixture | test (integration) | batch, git index | *(none in-repo)* | no analog |

**Files to modify (both exist, both tracked):**

| File | Role | Change | Why |
|---|---|---|---|
| `docs/superpowers/specs/2026-09-16-client-dossier-design.md` | spec | §4 tree: move `templates/` from repo root into `skills/dossier-init/` | D-06 says the tree "is to be amended during this phase"; O-4 says make it an explicit task |
| `CLAUDE.md` | project doc | record the amended tree, the `python3 ≥ 3.8` floor (O-5), and the first real build/test commands (`bash tests/run.sh`, `claude plugin validate .`) | CLAUDE.md C-1 ("the spec wins and this file must be updated") + its own closing line "No build, lint or test commands exist yet; add them here as they are created" |

---

## The Target Tree (the phase's real "pattern")

Verbatim from 01-RESEARCH.md lines 279-296 — this is the authoritative shape, amending spec §4:

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

12 template files per language variant × 2 = 24 template files.

**Template → scaffold target mapping** (the script needs this table explicitly):

| Template | Written to |
|---|---|
| `ACTORS.md` … `RELATIONSHIP.md` (7) | `dossier/<same name>` |
| `CONTEXT.md`, `DOCTRINE.md` | `knowledge/<same name>` |
| `README-dossier.md` | `dossier/README.md` |
| `README-sources.md` | `sources/README.md` |
| `README-outbound.md` | `outbound/README.md` |

**Anti-pattern, cited by the Claude Code docs as the single most common mistake:** never put
`skills/`, `agents/`, `commands/` or `hooks/` inside `.claude-plugin/`. Only `plugin.json` goes there.

---

## Pattern Assignments

### `.claude-plugin/plugin.json` (config, static)

**No in-repo analog.** Two binding sources agree on the shape.

Spec §4 (lines 231-234), verbatim:

> `.claude-plugin/plugin.json` exists from the first commit that ships a skill, in its minimal
> form (name, version, description), so that the plugin loads locally with
> `claude --plugin-dir .` during development

RESEARCH Pattern 2 resolves it to:

```json
{
  "name": "client-dossier",
  "description": "…",
  "version": "0.1.0"
}
```

- `name` is the **only required field**, kebab-case, no spaces.
- `name` is also the **skill namespace**: `skills/dossier-init/` becomes `/client-dossier:dossier-init`.
  Write the phase's acceptance steps with the namespaced form (Pitfall 2).
- Acceptance check: `claude plugin validate . --strict` must exit 0 (verified present in the local CLI 2.1.273).

**Weak cross-repo confirmation** — `/Users/samuel/Documents/dev/vibeflow-os/plugin/.claude-plugin/plugin.json`
(git-tracked, verified with `git ls-files`) is a real loaded plugin manifest on this machine. Its field
order is `name`, `displayName`, `version`, `description`, `author{name}`, `homepage`, `repository`,
`license`, `keywords`. It confirms the schema, but it is a **maximal** manifest; SCAF-08 asks for the
minimal one. Copy only the first four field names, in that order, and stop.

---

### `skills/dossier-init/SKILL.md` (skill, judgement tier, request-response)

**No in-repo analog.** Frontmatter convention below is confirmed by three tracked sibling skills.

**Frontmatter shape** — spec §4.1 (line 243): *"All skills follow the Agent Skills standard
(`SKILL.md` with `name` and `description` frontmatter)"*, and *"Descriptions are written for
triggering: they name the situations, not the features."*

```yaml
---
name: dossier-init
description: <situational, not feature-listing; under the 1,536-char description budget>
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/init.py *)
---
```

Two hard rules the planner must carry into the plan action:
1. **Folder name and `name:` must be identical** (`dossier-init`). Plugin skills take the last
   command segment from `name:`, not from the folder (Pitfall 2).
2. **`description` + `when_to_use` share a 1,536-character budget** and the listing truncates.
   Body under 500 lines (Pitfall 4).

**Bundled-resource reference pattern** (RESEARCH Pattern 1) — never a hard-coded relative path,
because the skill's working directory at invocation is *the user's dossier repo*, not the plugin:

```yaml
# Source: https://code.claude.com/docs/en/skills
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/render.sh *)
---
Run `${CLAUDE_SKILL_DIR}/scripts/render.sh <csv-file>` to render the chart.
```

Applied here: `Run ${CLAUDE_SKILL_DIR}/scripts/init.py --language fr --counterpart …`.
Companion variables: `${CLAUDE_PLUGIN_ROOT}` (for Phase 2's root `scripts/lint.py`),
`${CLAUDE_PROJECT_DIR}`, `${CLAUDE_PLUGIN_DATA}`.

**Caveat the tests depend on (A4):** `${CLAUDE_SKILL_DIR}` is a *harness-side substitution*, not an
env var. The Phase 1/2 bash runner must call `init.py` by explicit path.

**Body structure the skill must contain** (D-01..D-04, D-07, D-14..D-17 — the judgement steps the
script does *not* do). RESEARCH's flow diagram (lines 234-266) is the canonical ordering:

1. infer language (conversation → existing `CLAUDE.md`/`AGENTS.md`), propose as default — never
   silently English (D-03)
2. one grouped question for what is missing only; never re-ask what arguments already gave (D-01/D-02)
3. derive `confidential_names` short forms, show the list, let the user edit (D-04)
4. scan repo root with the FR/EN name table + content hints → proposed mapping → **human
   confirmation gate** → `git mv` (D-14/D-15); no confirmation ⇒ execute nothing
5. choose template variant: `templates/<lang>/` if lang ∈ {en, fr}, else `templates/en/` + translate (D-09)
6. run `${CLAUDE_SKILL_DIR}/scripts/init.py`; **if absent, perform the same procedure inline and
   say so** (D-07, mandatory per CLAUDE.md C-7)
7. report created / kept / renamed / ignored; **never commit** (D-15/D-17)

---

### `skills/dossier-init/scripts/init.py` (script, mechanics tier, file-I/O + idempotent batch)

**No in-repo analog.** Every literal it writes is specified verbatim; the scarce resource is
fidelity to those strings, not design.

**Constraint block** (CLAUDE.md C-5/C-6, D-05, O-5): Python 3 **standard library only**, target
≥3.8, fully argument-driven so the Phase 2 bash runner can call it non-interactively.

**Core pattern — idempotent create-if-missing.** RESEARCH lines 255-263:

```
for each target path:
  exists? ─ yes ─► skip, record "kept"
           └─ no ─► write, record "created"
```

D-08 forbids overwriting. This is the single highest-impact control in the phase: on an adopted
repository, overwriting destroys a living dossier. Never truncate.

**The one documented exception** (Pitfall 7 / Pattern 3 / D-16): for `AGENTS.md` and `CLAUDE.md`,
"skip if the file exists" is the *wrong* rule — the file may exist without the section. Use
marker-delimited replace:

```
<!-- client-dossier:start -->
…protocol pointer…
<!-- client-dossier:end -->
```

Markers present ⇒ replace the span between them. Markers absent ⇒ append the whole block.
Target rule: **`AGENTS.md` always** (create if absent), **`CLAUDE.md` only if it already exists**.
Provenance is honest: this is a convention (A1), locked by D-16, not specified by any standard.

**`dossier.yaml` — exact key order, spec §3.2 lines 142-157 verbatim.** Emit these ten keys in
this order; the Phase 2 linter parses this file, so a malformed emission breaks every later phase:

```yaml
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

Emit via a fixed f-string template. **Do not parse YAML in this phase** — parsing is Phase 2's
problem and the spec already prescribes a tiny YAML-subset parser there.

**The seven `.gitkeep` leaves, spec §3.2 lines 138-141 verbatim:**

> every leaf folder the scaffold creates and leaves empty (`sources/received/`,
> `sources/transcripts/raw/`, `knowledge/decisions/`, `knowledge/watch/`,
> `outbound/deliverables/`, `outbound/mails/`, `outbound/calls/`) gets a `.gitkeep`.
> The linter ignores `.gitkeep` files.

Write all seven **unconditionally**, not "if empty" (Pitfall 5). Corollary from DISC-2: after an
adoption rename, `knowledge/watch/` may already contain a `README.md` — the script must not choke
on a non-empty "leaf".

**Error-handling / security patterns** (no in-repo precedent; from RESEARCH's Security Domain):

| Concern | Required shape |
|---|---|
| `git mv` invocation | `subprocess.run([...], shell=False)` with an **argument list**. Never `os.system`, never an interpolated shell string. Prefix user paths with `--`. |
| `git mv` on untracked paths | `git ls-files --error-unmatch <path>` first; report untracked same-role folders separately (Pitfall 6, **O-2 open**) |
| YAML injection via a counterpart name | quote every scalar, escape `"` and `\`, strip control characters and newlines |
| Path traversal | **no path component is ever derived from user input in this phase** — all paths are fixed English constants (spec §3.2, CLAUDE.md C-3). Keep it that way. |
| Symlink escaping the repo | `os.path.realpath` each rename candidate; skip and report anything resolving outside the repo root |
| `git` absent | degrade to a reported failure, never a crash (CLAUDE.md C-8) |
| Writes under `sources/` | `.gitkeep` only (CLAUDE.md C-11) |
| Confidential names under `outbound/` | **never interpolate a counterpart name into anything under `outbound/`**; the D-11 examples use the spec's fictional "Jane Doe (Acme)" |

---

### `skills/dossier-init/templates/{en,fr}/*.md` (templates, transform)

This is where a real analog exists: **`/Users/samuel/Documents/dev/Project-POC-RELATION-CLIENT`**,
the live engagement repository the method comes from.

> **Confidentiality gate, restated (D-13):** structure only — folder names, file names, heading
> names, section order. Its content names real people and organisations and is **never copied,
> quoted or used as example text**. The full structural audit already lives in 01-RESEARCH.md
> lines 564-673 with every embedded name redacted; the planner should work from that audit and
> **not** re-open the origin repository. Even its `client/README.md` H1 contains real party names.

**Shared skeleton for all seven living files** (D-10 — faithful to spec §2.2, nothing more):

```markdown
# <Title, in the dossier language>

Last updated: YYYY-MM-DD

<!-- Updated when: <the "Updated when" text from spec §2.2 for this file> -->

## <Section 1, in the dossier language>

<!-- - Example: Jane Doe (Acme) asks for the deliverable by 2026-10-01 (call @12:34). -->

## <Section 2>
…
```

Four rules bind the skeleton:
- `Last updated:` is a **protocol keyword** — identical in `en/` and `fr/`, never translated.
- The "Updated when" rule is an **HTML comment**, not prose (D-10).
- The example fact line is an **HTML comment** (D-11): visible when editing, invisible when
  rendered, ignored by the linter, nothing to delete. A freshly scaffolded dossier must lint
  clean with zero warnings and contain zero fake facts.
- No sub-sections, no writing advice beyond the comment.

**Fact-line format inside the example comment** — spec §3.4 verbatim:

```
- <fact, one sentence, absolute dates> (<source>, <locator>).
```

Sources: `call @12:34`, `mail 2026-09-16 from Jane`, `brochure p. 4`, `internal note p. 15`.

**Per-file section lists** (spec §2.2 is binding; the origin column is the fidelity check — take
the FR heading wording from the RESEARCH audit table, lines 638-646):

| Template | Sections (spec §2.2 order) | Origin verdict |
|---|---|---|
| `ACTORS.md` | three groups: ordering party / end client / us (`###` per person) | ✅ exact |
| `HISTORY.md` | chronology + commitments in progress (ours, theirs) + upcoming | ⚠ DISC-4 — origin has one flat `## Engagements en cours`; **follow the spec** (two sub-headings or two labelled lists), noting the divergence |
| `LEARNINGS.md` | how they speak and think / what they expect of a document / what the case teaches / known pitfalls | ✅ exact, 4, same order |
| `TONE.md` | voice in one sentence / what is established / what each exchange added / structure of a long document / structure of a short message / **Refused** log | ⚠ DISC-3 — origin has *two* per-exchange sections; template ships **one generic** section that grows by bullet, not by heading |
| `CHANNELS.md` | video & recording etiquette / documents / mail addresses / call habits / the repository and its confidentiality level | ✅ exact, 5, same order |
| `OPEN-QUESTIONS.md` | three tables: answered / still open counterpart-side / what we would ask the end client | ⚠ DISC-3 — origin's first heading is dated (`16/09`, non-ISO); template uses an **undated generic heading**, and any date written later is `YYYY-MM-DD` |
| `RELATIONSHIP.md` | one-line status / metrics table / our view / their view as reconstructed / concrete improvements / sales opportunities by probability / points to keep in mind | ✅ exact, 7, same order — but ⚠ DISC-3: **role-generic labels only** ("notre point de vue", "leur point de vue, reconstitué"), never party names, which are unknown at scaffold time and confidential |
| `CONTEXT.md` | spec prescribes none. Recommended generic set: l'objet / ce qui est demandé maintenant / ce que le client a déjà / ce que nous apportons / les documents sources | partial — exclude the origin's engagement-specific per-exchange section |
| `DOCTRINE.md` | **two lists** (what we say / what we never say) + the vocabulary section, one sentence each | ✅ D-12 confirmed against reality (origin's last three `##` headings map one-to-one) |
| `README-dossier.md` | H1 + what the folder is for | thin — origin README has an H1 only |
| `README-sources.md` | H1 + immutability rule + `received/`, `transcripts/` (+ `raw/`) | **net-new, no analog** — origin has no `sources/README.md` |
| `README-outbound.md` | restates the **status header**, the `YYYY-MM-DD_slug` naming rule, and what each of `deliverables/`, `mails/`, `calls/` holds (spec §4.1) | spec-verbatim block below |

**Status-header block for `README-outbound.md`** — spec §3.3 lines 171-178 verbatim. Field names
and status values are protocol keywords: identical in `en/` and `fr/`. Only the values after the
colon are in the dossier's language.

```
Status: draft | reviewed by <name> | sent <date time> by <name>
To: <recipient>
Subject: <subject>            (mails)
Deadline: YYYY-MM-DD          (optional: when the draft has to be sent)
Written by: <human or "agent session, YYYY-MM-DD">
Rules: no confidential names; see knowledge/DOCTRINE.md
```

**`templates/fr/` is the variant that must be right first** (CONTEXT Specific Ideas: Samuel's own
dossiers are French). `templates/en/` is the *source* for any other language, translated by the
skill at scaffold time (spec §4.5).

---

### `tests/*.sh` (test, batch)

**No in-repo analog** — `tests/` does not exist. Framework is **bash + `python3` only**
(CLAUDE.md C-9); nothing else may be introduced.

RESEARCH's Wave 0 gap list is the file list: `run.sh` (dispatcher, sums exit codes), `lib.sh`
(`assert_file`, `assert_grep`, `mktemp -d` scratch repo), `test-init-empty.sh` (SCAF-01..04),
`test-init-fr.sh` (SCAF-07), `test-init-pointer.sh` (SCAF-05 + D-08 idempotence — run twice,
assert **exactly one** marker pair), `test-init-adopt.sh` + a **names-only** fixture (SCAF-06).

> **Fixture confidentiality gate:** the SCAF-06 fixture is built from folder and file *names* only.
> It must never contain a copy of the origin repository's file contents. The RESEARCH audit table
> is sufficient input to build it.

Two assertion patterns recur and should be factored into `lib.sh`:
- `grep -q '^Last updated:'` on each of the seven English filenames (SCAF-03)
- `grep -q` a known French heading **and** `grep -q 'Last updated:'` **and** assert no translated
  keyword (SCAF-07 / ROADMAP criterion 5)

Idempotence test shape: run init twice into the same directory, `diff -r` two snapshots → empty.

---

## Shared Patterns

Cross-cutting concerns; each applies to several of the files above.

### 1. Fixed English names, everywhere, no mapping table
**Source:** spec §3.2 + CLAUDE.md C-3.
**Apply to:** `init.py`, `SKILL.md`, every template, every test.
Folder and file names are fixed English and **not configurable**. The D-14 rename table is a
**one-way adoption-time table**, never a runtime mapping. No component may look up a localised name.

### 2. Protocol keywords are never translated
**Source:** spec §3.2 lines 129-133, verbatim:

> the `Last updated:` line of a living file, the field names of the status header (`Status:`,
> `To:`, `Subject:`, `Deadline:`, `Written by:`, `Rules:`) and the status values (`draft`,
> `reviewed by`, `sent`)

**Apply to:** all 24 templates, the outbound README, the Phase 2 lint fixtures.
`templates/fr/` keeps these strings **byte-identical** to `templates/en/`. This is ROADMAP success
criterion 5 and the thing Phase 2's linter greps for. No per-language label table, ever.

### 3. Idempotent create-if-missing (+ its single marker-comment exception)
**Source:** D-08; exception D-16 / Pitfall 7.
**Apply to:** `init.py` (every write), `test-init-pointer.sh`, the re-run smoke test.
See the `init.py` section for the two shapes.

### 4. English artefacts, localised content
**Source:** CLAUDE.md C-2.
**Apply to:** `SKILL.md`, `init.py`, `plugin.json`, tests, commit messages — all **English**.
`templates/fr/` bodies are French. This repo's own commit messages are English (recent history:
`docs(01): research phase domain`, `chore(gsd): add config.json …`).

### 5. Judgement in the skill, mechanics in the script, plus an inline fallback
**Source:** spec §4 principle + CLAUDE.md C-5 and C-7.
**Apply to:** the `SKILL.md` / `init.py` split.
Anything a regex can check goes in the script. And because C-7 is mandatory, **every mechanical
rule the script enforces must also be stated in `SKILL.md`** so a bare-skills harness with no
Python behaves the same (D-07). Budget the plan for writing the procedure twice.

### 6. Human confirmation before any destructive or outbound action
**Source:** D-15.
**Apply to:** the rename step of `SKILL.md`.
`git mv` runs only after an explicit confirmation; without it, nothing is executed. The skill
**never commits** — the human reviews and commits.

### 7. Don't hand-roll what the harness already provides
**Source:** RESEARCH "Don't Hand-Roll".
| Temptation | Use instead |
|---|---|
| Path arithmetic from `__file__` / `git rev-parse` to find plugin files | `${CLAUDE_SKILL_DIR}` / `${CLAUDE_PLUGIN_ROOT}` |
| `mv` + `git add`/`git rm` | `git mv` |
| Hand-written JSON schema check for the manifest | `claude plugin validate . --strict` |
| A general YAML parser in `init.py` | emit a fixed template; do not parse |
| A placeholder README per empty leaf | `.gitkeep` |

---

## Cross-Repo Conventions (advisory only)

Three genuinely reusable structural conventions found under `/Users/samuel/Documents/dev/`. All
three paths verified **git-tracked in their own repositories** with `git ls-files`. None is in
`client-dossier`; none is authoritative here. They are reported because they independently confirm
the shapes RESEARCH.md derived from the docs.

### C-A: `skills/<name>/SKILL.md` at repo root, frontmatter = `name` + `description` only
**Path:** `/Users/samuel/Documents/dev/prompt-eval-harness/skills/prompt-eval-harness/SKILL.md`
(Samuel's own repo; tracked).
Layout: `skills/<skill-name>/SKILL.md` + a sibling `README.md`, skill name == folder name.
Frontmatter is exactly two keys. The `description` is written situationally and ends with an
explicit trigger-phrase list ("Trigger on …") — the same authoring style spec §4.1 asks for
("name the situations, not the features"). **Applicable to:** `skills/dossier-init/SKILL.md`.

### C-B: bundled resources inside the skill folder (the D-06 layout, in the wild)
**Path:** `/Users/samuel/Documents/dev/vibeflow-os/plugin/skill-creator/skills/skill-creator/`
(tracked; this is the vendored Anthropic skill-creator).
Layout observed: `SKILL.md` + `scripts/` (8 `.py` files + `__init__.py`) + `references/` +
`assets/` + `agents/`. Its own `SKILL.md` documents the convention it follows: *"scripts/ —
Executable code for deterministic/repetitive tasks"*, and advises bundling a script once rather
than letting each invocation reinvent it — which is exactly D-05's rationale.
**Applicable to:** D-06's `skills/dossier-init/{scripts,templates}/`. Confirms the layout is real
and installed on this machine.
**Caveat:** it uses the open standard's canonical `assets/`, not `templates/` — the live instance
of open question **O-1**. D-06 locked `templates/`; the divergence is naming-only and low risk.

### C-C: `.claude-plugin/plugin.json` field shape
**Path:** `/Users/samuel/Documents/dev/vibeflow-os/plugin/.claude-plugin/plugin.json` (tracked).
Confirms the schema and the `.claude-plugin/` sibling-of-`skills/` placement (that repo also keeps
a parallel `.codex-plugin/plugin.json` with the same `name`/`version`/`description` — the dual-manifest
shape spec §4 plans for Phase 7). See the `plugin.json` section for what to take and what to leave.

### Not found (searched, genuinely absent)
- **`${CLAUDE_SKILL_DIR}` / `${CLAUDE_PLUGIN_ROOT}` usage:** zero hits across every `.md`, `.json`,
  `.py` and `.sh` under `/Users/samuel/Documents/dev/` outside `.planning/` research notes. The
  pattern rests entirely on RESEARCH.md's cited Claude Code docs — no local precedent to imitate.
- **Marker-comment idempotent section (`<!-- …:start -->`):** zero hits. D-16's pattern has no
  local precedent; it is a convention (A1), and the planner should specify the exact marker syntax
  rather than expect an example.
- **A Python stdlib-only scaffolding script that builds a directory tree idempotently:** none
  found. The sibling scaffolders are bash (`vibeflow-os/plugin/installer/scripts/*.sh`) and solve a
  different problem. `init.py` has no model to copy.

---

## No Analog Found

Files with no analog anywhere — the planner works from spec verbatim blocks and RESEARCH.md alone:

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `skills/dossier-init/scripts/init.py` | script | file-I/O, idempotent batch | First script in the repo; no stdlib-only scaffolder found in any sibling project either. Fully specified by spec §3.2 + D-08 instead. |
| `templates/{en,fr}/README-sources.md` | template | static | The origin repo has **no** `sources/README.md`. Net-new; derive from spec §2.1's immutability regime and §3.2's `received/` + `transcripts/ (+ raw/)`. |
| `tests/run.sh`, `tests/lib.sh`, `tests/test-init-*.sh` (5 files) | test | batch | First tests in the repo. Constraint (bash + python3 only) is known; shape is not. |
| The `AGENTS.md` protocol-pointer block (content) | doc fragment | static | No precedent for the pointer's wording. Constraint from CLAUDE.md C-12: **do not pre-empt the Stop-hook v1 question** in the pointer text — that is decided in Phase 3 with Samuel. |
| `.claude-plugin/plugin.json` | config | static | No in-repo analog; shape is unambiguous (spec §4 + RESEARCH Pattern 2), and `claude plugin validate --strict` is the mechanical check. |

---

## Open Questions the Planner Must Resolve (carried from RESEARCH.md)

These are pattern-relevant because each changes what a file must contain:

| # | Question | Effect on the files above |
|---|---|---|
| O-1 | `templates/` vs `assets/` inside the skill folder | Directory name in the tree, and every path in `SKILL.md`. Recommendation: keep `templates/` (D-06 locked). |
| O-2 | `git mv` on untracked same-role folders | A branch in `SKILL.md`'s rename step and a line in the proposal output. |
| O-3 | DISC-1: `sources/internes/` + `sources/plaquette/` unmapped | SCAF-06's acceptance case and `test-init-adopt.sh`'s golden file. **Ask Samuel.** |
| O-4 | Does the spec §4 amendment land in this phase's commits? | Two explicit plan tasks (spec edit + CLAUDE.md edit), not incidental. |
| O-5 | Minimum Python version | A declared floor in CLAUDE.md and a syntax subset for `init.py`. |

---

## Metadata

**Analog search scope:** `/Users/samuel/Documents/dev/client-dossier` (full `git ls-files` + `find`);
`/Users/samuel/Documents/dev/` at depth ≤5 for `SKILL.md`, `.claude-plugin/plugin.json`, bundled
`scripts/` folders, `${CLAUDE_SKILL_DIR}` usage and marker-comment patterns;
`/Users/samuel/Documents/dev/Project-POC-RELATION-CLIENT` top-level listing only (structure, no bodies).
**Files scanned:** 18 tracked in-repo, ~40 sibling `SKILL.md` candidates, 2 sibling manifests,
1 sibling packaging script.
**Tracked-source gate:** all three cross-repo paths verified non-empty under `git ls-files` in their
own repositories. `/Users/samuel/.claude/plugins/` install mirrors were deliberately **not** used.
**Pattern extraction date:** 2026-09-16

*Phase: 01-scaffold-templates*
