# client-dossier

`client-dossier` is a plugin for coding agents that turns a git repository into the memory and the
workbench of a relationship with an external party: a client, a partner, a prospect, an
intermediary, a recruiter. It scaffolds a fixed layout, teaches the agent to read the dossier before
acting and to update it before handing back, and checks the mechanical rules with a linter and hooks.
It never sends anything and never renders documents.

## What it is

A dossier repository has four regimes:

- `sources/` is immutable. Mails, transcripts, brochures and notes are filed as received and never
  edited; a correction goes in the living files.
- `dossier/` is the living part: seven files in which every fact is one sentence, with an absolute
  date and its source in parentheses.
- `knowledge/` holds the context, the doctrine every outgoing document is checked against, and the
  decisions and watch notes.
- `outbound/` holds the drafts. Each opens with a status header, and only a human sends a reviewed
  draft: the agent never marks a draft as sent.

The work is split three ways. Skills carry judgement (what to read first, how to write a fact, how to
review a draft). Scripts carry mechanics (anything a regular expression can check lives in
`scripts/lint.py`). Hooks carry reminders (a pointer at session start, a guard on `sources/`, a check
at the end of a turn), and every rule a hook enforces is also stated in a skill, so a harness without
hooks behaves the same way.

## The dossier layout

```text
dossier.yaml     the configuration: language, counterparts, confidential names, staleness
sources/         immutable material, filed as received
dossier/         the seven living files
knowledge/       context, doctrine, decisions, watch
outbound/        drafts, mails, call preparation, deliverables
```

These folder and file names are fixed English names and are never configurable. An existing
repository adopts them through `git mv` renames that `dossier-init` proposes and that you confirm.

The protocol keywords are English too, whatever language the dossier is written in: the
`Last updated:` label, the status-header fields `Status:`, `To:`, `Subject:`, `Deadline:`,
`Written by:` and `Rules:`, and the status values `draft`, `reviewed by` and `sent`. Only headings,
examples and content follow the language set in `dossier.yaml`.

## Installation

Pick the target that matches your harness. Claude Code gets everything (skills, hooks, agents and the
linter). The other targets get the skills and, where the harness supports it, a little more; each
subsection says what is missing.

### Claude Code

Inside Claude Code:

```text
/plugin marketplace add samuel-neveugall/client-dossier
/plugin install client-dossier@client-dossier
```

The same from a shell:

```bash
claude plugin marketplace add samuel-neveugall/client-dossier
claude plugin install client-dossier@client-dossier
```

To follow a release instead of the default branch, pin the tag once it exists:

```bash
claude plugin marketplace add samuel-neveugall/client-dossier@v1.0.0
```

A path to a local clone works as the marketplace source too. Install from a clean clone: a
local-path install copies the working tree as it is, including anything uncommitted.

### Codex

```bash
codex plugin marketplace add samuel-neveugall/client-dossier
codex plugin add client-dossier@client-dossier
```

Add `--ref v1.0.0` to the first command to pin a release.

- Codex runs the plugin's hooks only after you trust them in `/hooks`. Until then the skills still
  carry every rule the hooks would enforce.
- Codex's custom agents are not plugin-bundled, so `fact-extractor` and `doctrine-reviewer` are not
  used there: the skills run the same extraction and the same review inline.
- File edits made through `apply_patch` are judged by the sources guard like Claude Code's Write
  family.
- OpenAI's public plugin directory does not list plugins with lifecycle hooks, so this plugin is
  installed from its own marketplace, as above.

### Agent Skills harnesses (Cursor, Copilot CLI, Gemini CLI, OpenCode)

With the `skills` command-line tool:

```bash
npx skills add samuel-neveugall/client-dossier
```

The version tested for this plugin is `skills@1.7.0`; to run exactly that one:

```bash
npx skills@1.7.0 add samuel-neveugall/client-dossier
```

Or copy each folder of `skills/` into the harness's skills folder by hand.

What this install loses. A bare-skills install carries the six skill folders and nothing else, so it
has no `scripts/lint.py` (the skills state the linter's rules and check them by reading), none of the
three hooks (the `dossier` skill states every rule they enforce), and neither of the two agents
`fact-extractor` and `doctrine-reviewer` (the skills run the extraction and the review inline). The
private scripts copied with a skill, such as the one that scaffolds a dossier, are referenced as
`${CLAUDE_SKILL_DIR}/...`. Outside Claude Code that variable is not replaced, so the skill treats
those scripts as absent and runs its stated fallback instead.

### Without a plugin (AGENTS.md only)

`dossier-init` writes a protocol pointer into the repository's `AGENTS.md` (and into `CLAUDE.md` when
that file already exists). Any harness that reads one of them is told the core rules with no plugin
installed at all: read `dossier/` and `knowledge/CONTEXT.md` before acting, update the living files
before handing back, write each fact as one dated, sourced sentence, never edit `sources/`, never send
anything, never name a confidential party in `outbound/`. This is the lightest install and the weakest
one: the pointer is all there is, with no skill to carry the detail, no linter and no hook.
