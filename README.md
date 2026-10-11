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
  family: a patch that adds, updates, deletes or moves a file under `sources/` is denied. This is
  checked against the guard's input contract, not on a live Codex run.
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

## Usage

In Claude Code the five task skills are slash commands, and arguments are passed through:

- `/client-dossier:dossier-init` scaffolds a dossier, or adopts an existing repository.
- `/client-dossier:dossier-ingest` files a source and extracts dated, sourced facts from it.
- `/client-dossier:dossier-draft` writes an outbound draft with its status header, then has it reviewed.
- `/client-dossier:dossier-call` prepares a call and writes it up afterwards.
- `/client-dossier:dossier-status` reports where things stand: what is due, overdue, stale or waiting.

They also trigger on plain requests ("where do we stand with the client?"), so you rarely need the
slash form. The `dossier` skill carries the protocol and loads itself inside a dossier: at the start
of a session a reminder points the agent to it when a `dossier.yaml` is found in the working directory
or above.

From a clone of this repository the linter runs on its own:

```bash
python3 scripts/lint.py [PATH]
```

It lints the dossier holding `PATH` (the current directory by default), walking upward to the nearest
`dossier.yaml`. It is read-only and has no repair mode. Exit codes: 0 no error (warnings allowed),
1 at least one error, 2 no `dossier.yaml` found upward or unreadable, 3 internal error.

## Limits

Two protections are heuristics. This section says where they stop, so you do not rely on them past
that point.

### The sources guard

In Claude Code a PreToolUse hook denies the likely shortcuts for changing a file under `sources/`. It
denies:

- in-place edits such as `sed -i`, `gsed -i`, `perl -i`, `awk -i inplace`, `ed`, `vim -es`, `sponge`
  and `patch`;
- `rm`, and `mv` out of `sources/`;
- a redirection (`>` or `>>`) or `tee` onto a path under `sources/`, and `truncate`;
- the same verbs behind the wrappers `timeout`, `nice`, `ionice`, `stdbuf` and `caffeinate`, and
  inside `bash -c` strings;
- the Write, Edit, MultiEdit and NotebookEdit tools on a path under `sources/`.

Copying a new file into `sources/` is allowed: that is how a source is filed.

The guard reads the command text and nothing else, so it does not see what the text only builds at
run time: `eval`, interpreters such as `python3 -c`, command substitutions and process
substitutions, variables, loops over globs, a patch piped or read in rather than written out in the
command (`printf '%s\n' … | apply_patch`), shells nested deeper than two levels, and very large
commands (past its size bounds it only refuses a visible `sources` component). A `cd` through a
variable is guessed, not followed, and a `cp` onto the name of an existing source is not told apart
from filing a new one.

On Codex, edits made through `apply_patch` are judged too, by the headers of the patch.

So the skill's rule is the real boundary: nothing under `sources/` is ever modified by any route, seen
by the guard or not. The guard catches the shortcut an agent is likely to take under pressure; it is
not a security control. A correction goes in a living file as a dated, sourced line that quotes the
source as received.

### Confidential names

`dossier.yaml` can list confidential names that must not appear under `outbound/` unless consent is
recorded with its source. `scripts/lint.py` matches those names tolerantly (markup between words,
apostrophe look-alikes, a hyphen at the end of a line, percent-encoded file names, a small table of
Cyrillic and Greek homoglyphs). It does not catch abbreviations, acronyms, nicknames or translations of
a name (`BT` for `British Telecom`), nor homoglyphs outside that table. The `doctrine-reviewer` agent,
reading a draft, is the only net for those cases, so a draft that might mention a confidential party
under another name still needs a human read before it is sent.

## Requirements

- `python3` 3.8 or newer, standard library only. The linter, the hooks and the bundled scripts need
  nothing else.
- `git`.
- Optional: `pdftotext` (from poppler) to read PDFs. Without it a PDF is still filed under
  `sources/`, and the extraction is reported as skipped.

## Versioning

The plugin follows semantic versioning. `CHANGELOG.md` records every release in the Keep a Changelog
format. Each release is one git tag `vX.Y.Z`, and the Claude Code and Codex manifests are always at the
same version.

`scripts/release.sh <version>` cuts a release from a clean checkout: it sets the version in both
manifests, adds the changelog heading and creates the annotated tag locally. It never pushes: pushing
the tag, publishing to a marketplace and making the repository public are done by hand.

## License

MIT, Copyright (c) 2026 Samuel Neveu. See [LICENSE](LICENSE).

## Privacy

The plugin never sends anything: no dossier content is uploaded or posted anywhere by it. Everything
stays in your git repository, and what you do with a remote is up to you. The only network access is
the download of a link you ask `dossier-ingest` to file. Install from GitHub or from a clean clone: a
local-path install copies the working tree as it is, uncommitted files included.
