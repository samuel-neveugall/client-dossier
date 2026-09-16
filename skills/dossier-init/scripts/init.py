#!/usr/bin/env python3
# vibeflow:allow-large-file -- mechanics-tier scaffold script; grew past the
# 300-line guard when plan 01-02 wired the eleven remaining templates and
# resolve_template_dir(). Splitting deferred: TEMPLATE_MAP, the write loop
# and the variant resolution are one cohesive scaffold pass (plan 01-01's
# established pattern). Tracked in 01-02-SUMMARY.md and .planning/WINDOWS.md.
"""Scaffold a client-dossier repository.

Mechanics tier only (spec principle: "skills carry the judgement, scripts
carry the mechanics"). Every input arrives as a command-line argument — this
script never prompts, never reads a TTY, and never shells out. Judgement
(the grouped question, language inference, rename detection, translation)
lives in skills/dossier-init/SKILL.md.

Python 3 standard library only, targeting Python >= 3.8.
"""

import argparse
import datetime
import os
import re
import sys
from pathlib import Path

# The twelve directories the scaffold creates (spec Sec3.2).
FOLDERS = (
    "sources",
    "sources/received",
    "sources/transcripts",
    "sources/transcripts/raw",
    "dossier",
    "knowledge",
    "knowledge/decisions",
    "knowledge/watch",
    "outbound",
    "outbound/deliverables",
    "outbound/mails",
    "outbound/calls",
)

# The seven leaves spec Sec3.2 names verbatim. Git does not track empty
# folders, so each gets a .gitkeep, written unconditionally (never "if
# empty") -- an adopted repository can hold a folder that is empty today but
# never survived a clone, and after an adoption rename a "leaf" may already
# hold a file.
GITKEEP_LEAVES = (
    "sources/received",
    "sources/transcripts/raw",
    "knowledge/decisions",
    "knowledge/watch",
    "outbound/deliverables",
    "outbound/mails",
    "outbound/calls",
)

# Ordered mapping: bundled template filename -> target path under the
# dossier root. Order matches spec Sec3.2 scaffold order, so the report
# reads top-down: the seven living files, the two knowledge stubs, then
# the three folder READMEs (each renamed to README.md at its target).
TEMPLATE_MAP = {
    "ACTORS.md": "dossier/ACTORS.md",
    "HISTORY.md": "dossier/HISTORY.md",
    "LEARNINGS.md": "dossier/LEARNINGS.md",
    "TONE.md": "dossier/TONE.md",
    "CHANNELS.md": "dossier/CHANNELS.md",
    "OPEN-QUESTIONS.md": "dossier/OPEN-QUESTIONS.md",
    "RELATIONSHIP.md": "dossier/RELATIONSHIP.md",
    "CONTEXT.md": "knowledge/CONTEXT.md",
    "DOCTRINE.md": "knowledge/DOCTRINE.md",
    "README-dossier.md": "dossier/README.md",
    "README-sources.md": "sources/README.md",
    "README-outbound.md": "outbound/README.md",
}

# The line a rendered living-file template carries before substitution.
_LAST_UPDATED_RE = re.compile(r"^(Last updated:[ \t]*)YYYY-MM-DD[ \t]*$", re.MULTILINE)


def yaml_quote(value):
    """Return a double-quoted YAML scalar, safe for any user-supplied string.

    Strips every character below 0x20 (newlines included), then escapes
    backslashes and double quotes -- in that order, so a backslash inserted
    by the first escape is never re-escaped by the second.
    """
    cleaned = "".join(ch for ch in value if ord(ch) >= 0x20)
    cleaned = cleaned.replace("\\", "\\\\").replace('"', '\\"')
    return '"' + cleaned + '"'


def parse_counterpart(spec):
    """Parse `NAME|ROLE|CONTACT;CONTACT` into a dict.

    Role and contacts are optional. A missing field becomes empty and is
    then omitted from the returned dict entirely -- never written blank.
    """
    parts = spec.split("|")
    name = parts[0].strip() if len(parts) > 0 else ""
    role = parts[1].strip() if len(parts) > 1 else ""
    contacts_field = parts[2] if len(parts) > 2 else ""

    entry = {"name": name}
    if role:
        entry["role"] = role
    if contacts_field:
        contacts = [c.strip() for c in contacts_field.split(";") if c.strip()]
        if contacts:
            entry["contacts"] = contacts
    return entry


def render_dossier_yaml(cfg):
    """Emit dossier.yaml's ten spec Sec3.2 keys, in spec order.

    Emission only -- this script never parses YAML. Parsing an existing
    dossier.yaml is Phase 2's problem, with the tiny YAML-subset parser the
    spec already prescribes.
    """
    lines = ["# dossier.yaml", "version: 1", "language: {}".format(cfg["language"]), "counterparts:"]

    for counterpart in cfg["counterparts"]:
        lines.append("  - name: {}".format(yaml_quote(counterpart["name"])))
        if "role" in counterpart:
            lines.append("    role: {}".format(counterpart["role"]))
        if "contacts" in counterpart:
            quoted = ", ".join(yaml_quote(c) for c in counterpart["contacts"])
            lines.append("    contacts: [ {} ]".format(quoted))

    confidential_names = cfg["confidential_names"]
    if confidential_names:
        quoted_names = ", ".join(yaml_quote(n) for n in confidential_names)
        lines.append("confidential_names: [ {} ]".format(quoted_names))
    else:
        lines.append("confidential_names: []")

    lines.append("consent_recorded: {}".format("true" if cfg["consent_recorded"] else "false"))
    lines.append("consent_source: {}".format(yaml_quote(cfg["consent_source"])))
    lines.append("timestamps: {}".format(yaml_quote(cfg["timestamps"])))
    lines.append("date_format: {}".format(yaml_quote(cfg["date_format"])))
    lines.append("status_header: {}".format(cfg["status_header"]))
    lines.append("staleness_days: {}".format(cfg["staleness_days"]))

    return "\n".join(lines) + "\n"


def render_template(text, today):
    """Substitute today's date on the `Last updated:` line only.

    Anchored to that exact line so the same YYYY-MM-DD token appearing
    elsewhere in a template body (a status-header illustration, for
    instance) survives verbatim.
    """
    return _LAST_UPDATED_RE.sub(lambda m: m.group(1) + today, text)


def under_root(root, path):
    """True when the resolved `path` is `root` or lives under it."""
    resolved_root = os.path.realpath(root)
    resolved_path = os.path.realpath(path)
    return os.path.commonpath([resolved_root, resolved_path]) == resolved_root


def resolve_template_dir(templates_root, language, variant):
    """Decide which templates/<name>/ directory to scaffold from (D-09).

    - an explicit `variant` wins outright. If `templates_root/<variant>/`
      does not exist (or would resolve outside `templates_root`), the
      caller must report the name on stderr and exit before writing
      anything -- this function signals that case by returning `None` as
      the first element.
    - otherwise, if `templates_root/<language>/` exists, use it.
    - otherwise fall back to `templates_root/en/`, and say so: the caller
      prints the fallback note as part of the `templates: <variant>`
      report line, which is the mechanical handoff to the skill's
      translation step (SCAF-07) -- this script never translates anything.

    Returns (path_or_none, report_variant, fallback_note_or_none).
    """
    if variant:
        variant_dir = templates_root / variant
        if not under_root(templates_root, variant_dir) or not variant_dir.is_dir():
            return None, variant, None
        return variant_dir, variant, None

    language_dir = templates_root / language
    if under_root(templates_root, language_dir) and language_dir.is_dir():
        return language_dir, language, None

    fallback_note = (
        "requested language {!r} has no template variant; scaffolded from "
        "templates/en/ -- translate the created files".format(language)
    )
    return templates_root / "en", "en", fallback_note


def write_if_missing(path, text):
    """Write `text` to `path` only if it does not already exist.

    Returns "created" or "kept". Never opens an existing path for writing --
    no truncation, no overwrite, no merge. This is D-08, the single control
    that stops a re-run from destroying a living dossier.
    """
    if os.path.exists(path):
        return "kept"
    parent = os.path.dirname(path)
    if parent:
        os.makedirs(parent, exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(text)
    return "created"


def build_parser():
    parser = argparse.ArgumentParser(
        description="Scaffold a client-dossier repository (mechanics tier; never interactive)."
    )
    parser.add_argument("--target", default=".", help="Path to the repository to scaffold.")
    parser.add_argument("--language", default="en", help="Dossier content language code.")
    parser.add_argument(
        "--template-variant",
        default=None,
        help="Force a specific templates/<name>/ directory, overriding --language resolution.",
    )
    parser.add_argument(
        "--counterpart",
        action="append",
        default=[],
        help="NAME|ROLE|CONTACT;CONTACT (role and contacts optional). Repeatable.",
    )
    parser.add_argument(
        "--confidential-name",
        dest="confidential_names",
        action="append",
        default=[],
        help="A name never allowed under outbound/. Repeatable.",
    )
    parser.add_argument("--consent-recorded", choices=["true", "false"], default="false")
    parser.add_argument("--consent-source", default="")
    parser.add_argument("--timestamps", default="@mm:ss")
    parser.add_argument("--date-format", default="YYYY-MM-DD")
    parser.add_argument("--status-header", default="required")
    parser.add_argument("--staleness-days", type=int, default=7)
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)

    target_root = os.path.realpath(args.target)
    if not os.path.isdir(target_root):
        print("error: --target {!r} is not a directory".format(args.target), file=sys.stderr)
        return 1

    # Resolve the template variant before any write, so an unknown
    # --template-variant aborts having written nothing (T-01-10).
    templates_root = Path(__file__).resolve().parent.parent / "templates"
    templates_dir, report_variant, fallback_note = resolve_template_dir(
        templates_root, args.language, args.template_variant
    )
    if templates_dir is None:
        print(
            "error: unknown --template-variant {!r}: {} does not exist".format(
                args.template_variant, templates_root / args.template_variant
            ),
            file=sys.stderr,
        )
        return 1

    if fallback_note:
        print("templates: {} ({})".format(report_variant, fallback_note))
    else:
        print("templates: {}".format(report_variant))

    results = []

    for folder in FOLDERS:
        folder_path = os.path.join(target_root, folder)
        if not under_root(target_root, folder_path):
            print("error: refusing to create {} outside the target root".format(folder_path), file=sys.stderr)
            return 1
        os.makedirs(folder_path, exist_ok=True)

    for leaf in GITKEEP_LEAVES:
        gitkeep_path = os.path.join(target_root, leaf, ".gitkeep")
        if not under_root(target_root, gitkeep_path):
            print("error: refusing to write {} outside the target root".format(gitkeep_path), file=sys.stderr)
            return 1
        status = write_if_missing(gitkeep_path, "")
        results.append((status, os.path.relpath(gitkeep_path, target_root)))

    counterparts = [parse_counterpart(spec) for spec in args.counterpart]
    cfg = {
        "language": args.language,
        "counterparts": counterparts,
        "confidential_names": args.confidential_names,
        "consent_recorded": args.consent_recorded == "true",
        "consent_source": args.consent_source,
        "timestamps": args.timestamps,
        "date_format": args.date_format,
        "status_header": args.status_header,
        "staleness_days": args.staleness_days,
    }

    dossier_yaml_path = os.path.join(target_root, "dossier.yaml")
    if not under_root(target_root, dossier_yaml_path):
        print("error: refusing to write {} outside the target root".format(dossier_yaml_path), file=sys.stderr)
        return 1
    status = write_if_missing(dossier_yaml_path, render_dossier_yaml(cfg))
    results.append((status, "dossier.yaml"))

    today = datetime.date.today().isoformat()

    for template_name, target_rel in TEMPLATE_MAP.items():
        template_path = templates_dir / template_name
        target_path = os.path.join(target_root, target_rel)
        if not under_root(target_root, target_path):
            print("error: refusing to write {} outside the target root".format(target_path), file=sys.stderr)
            return 1
        with open(template_path, "r", encoding="utf-8") as handle:
            raw_text = handle.read()
        rendered_text = render_template(raw_text, today)
        status = write_if_missing(target_path, rendered_text)
        results.append((status, os.path.relpath(target_path, target_root)))

    for status, relative_path in results:
        print("{}: {}".format(status, relative_path))

    created_count = sum(1 for status, _ in results if status == "created")
    kept_count = sum(1 for status, _ in results if status == "kept")
    print("done: {} created, {} kept".format(created_count, kept_count))

    return 0


if __name__ == "__main__":
    sys.exit(main())
