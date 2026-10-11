#!/usr/bin/env bash
# tests/test-evals-shape.sh -- the free shape and scaffold test of the
# `claude plugin eval` routing suite (DIST-06; decisions D-07 and D-11 of
# phase 7; plan 07-04).
#
# FREE: nothing here calls a model. The paid run of the suite is plan 07-07's,
# run by the agent, and is never part of tests/run.sh. This test pins what a
# paid run would otherwise discover late and expensively:
#   - the set of case folders under evals/ (EXPECTED_CASES);
#   - the documented shape of every prompt.md, case.yaml and graders/*.md
#     (code.claude.com/docs/en/plugin-evals "Eval suite reference": an unknown
#     key is a load error);
#   - the least-privilege tool grant, [Read, Glob, Grep, Skill], on every case;
#   - that every tool_used grader targets the Skill tool and names a skill
#     folder that exists under skills/;
#   - that every scaffold script runs for free in a fresh workspace with the
#     minimal environment `claude plugin eval --scaffold` documents, and builds
#     what the case expects;
#   - that evals/results/ (run artefacts) is git-ignored.
#
# bash 3.2, no arrays; set -u only (lib.sh).
set -u

# shellcheck source=./lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# The case folders, sorted and space-separated. Extended task by task.
EXPECTED_CASES='call-prepare deal-status draft-reply ingest-transcript init-new-client write-to-client'

EVALS_DIR="$REPO_ROOT/evals"
CASES_DIR="$EVALS_DIR/routing"

# --- the set of case folders (every folder holding a prompt.md) ---
ACTUAL_CASES="$(find "$EVALS_DIR" -name prompt.md -not -path "$EVALS_DIR/results/*" 2>/dev/null \
  | while IFS= read -r p; do basename "$(dirname "$p")"; done | sort | tr '\n' ' ' | sed 's/ $//')"
assert_eq "$EXPECTED_CASES" "$ACTUAL_CASES" 'the case folders under evals/ are exactly the expected set'

# --- the documented shape of each case, through one python3 pass per case ---
for c in $EXPECTED_CASES; do
  dir="$CASES_DIR/$c"
  if [ ! -d "$dir" ]; then
    echo "FAIL: case folder missing: $dir" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    continue
  fi
  CHECKS_STATUS=0
  CHECKS="$(python3 - "$dir" "$REPO_ROOT" <<'PY' 2>&1
import os
import re
import sys

case_dir, repo_root = sys.argv[1], sys.argv[2]
case = os.path.basename(case_dir)

PROMPT_KEYS = {
    "schema_version", "name", "description", "tags", "plugins", "runs",
    "expected_outcome", "model", "max_turns", "timeout_seconds",
    "allowed_tools", "append_system_prompt", "env",
}
COMMON_GRADER_KEYS = {"type", "weight", "arm"}
GRADER_OPTIONS = {
    "regex": {"pattern", "flags", "match", "target"},
    "tool_used": {"tool", "input_match", "min", "max"},
    "tool_order": {"before", "after"},
    "file_exists": {"path", "exists"},
    "llm": {"criteria", "focus"},
    "baseline": {"baseline_file", "criteria"},
}
REGEX_TARGETS = {"last_message", "trace", "files"}


def emit(label, expected, actual):
    def clean(value):
        text = str(value).replace("\t", " ").replace("\n", " ").strip()
        return text or "-"
    print("\t".join([clean(label), clean(expected), clean(actual)]))


def split_front(text):
    """Return (frontmatter lines, body) or (None, text) without a frontmatter."""
    if not text.startswith("---\n"):
        return None, text
    end = text.find("\n---\n", 3)
    if end == -1:
        if text.endswith("\n---"):
            return text[4:-4].split("\n"), ""
        return None, text
    return text[4:end].split("\n"), text[end + 5:]


def unquote(value):
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"":
        inner = value[1:-1]
        return inner.replace("''", "'") if value[0] == "'" else inner
    return value


def parse_scalar(value):
    value = value.strip()
    if value.startswith("[") and value.endswith("]"):
        inner = value[1:-1].strip()
        return [unquote(item) for item in inner.split(",")] if inner else []
    return unquote(value)


def parse_flat(lines):
    """A `key: value` subset: top-level keys only; returns (dict, bad lines)."""
    data, bad = {}, []
    for line in lines:
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        match = re.match(r"^([A-Za-z_][A-Za-z0-9_]*):(?:\s+(.*))?$", line)
        if not match:
            bad.append(line)
            continue
        data[match.group(1)] = parse_scalar(match.group(2) or "")
    return data, bad


def read(path):
    with open(path, encoding="utf-8") as handle:
        return handle.read()


# --- prompt.md ---
prompt_path = os.path.join(case_dir, "prompt.md")
fm_lines, body = split_front(read(prompt_path))
emit("prompt.md has a frontmatter", "yes", "yes" if fm_lines is not None else "no")
fm, bad = parse_flat(fm_lines or [])
emit("prompt.md frontmatter parses as key: value lines", "none", ",".join(bad) or "none")
emit("prompt.md keys are documented keys", "none", ",".join(sorted(set(fm) - PROMPT_KEYS)) or "none")
emit("allowed_tools is exactly the read-only routing grant",
     "Read,Glob,Grep,Skill", ",".join(fm.get("allowed_tools", [])) if isinstance(fm.get("allowed_tools"), list) else "not a list")
tags = fm.get("tags", [])
emit("tags include routing", "yes", "yes" if isinstance(tags, list) and "routing" in tags else "no")
emit("prompt body is not empty", "yes", "yes" if body.strip() else "no")
emit("prompt body names no skill", "none", ",".join(re.findall(r"dossier-[a-z]\w*", body, re.I)) or "none")

# --- graders ---
graders_dir = os.path.join(case_dir, "graders")
grader_files = sorted(f for f in os.listdir(graders_dir) if f.endswith(".md")) if os.path.isdir(graders_dir) else []
emit("at least one grader", "yes", "yes" if grader_files else "no")

skill_dirs = {d for d in os.listdir(os.path.join(repo_root, "skills"))
              if os.path.isdir(os.path.join(repo_root, "skills", d))}
tool_graders = {}  # skill name -> list of (min, max)
for name in grader_files:
    g_lines, g_body = split_front(read(os.path.join(graders_dir, name)))
    g, g_bad = parse_flat(g_lines or [])
    tag = "grader " + name
    emit(tag + ": frontmatter parses", "none", ",".join(g_bad) or ("none" if g_lines is not None else "no frontmatter"))
    emit(tag + ": body is empty (frontmatter only)", "yes", "yes" if not g_body.strip() else "no")
    gtype = g.get("type")
    emit(tag + ": type is a documented type", "yes", "yes" if gtype in GRADER_OPTIONS else "no (%s)" % gtype)
    if gtype not in GRADER_OPTIONS:
        continue
    allowed = COMMON_GRADER_KEYS | GRADER_OPTIONS[gtype]
    emit(tag + ": keys are documented for its type", "none", ",".join(sorted(set(g) - allowed)) or "none")
    for bound in ("min", "max"):
        if bound in g:
            emit(tag + ": %s is an integer" % bound, "yes", "yes" if re.fullmatch(r"\d+", str(g[bound])) else "no")
    if "min" in g and "max" in g and re.fullmatch(r"\d+", str(g["min"])) and re.fullmatch(r"\d+", str(g["max"])):
        emit(tag + ": min is not above max", "yes", "yes" if int(g["min"]) <= int(g["max"]) else "no")
    if gtype == "tool_used":
        emit(tag + ": tool is Skill", "Skill", g.get("tool", "-"))
        names = re.findall(r"dossier(?:-[a-z]+)?", g.get("input_match", ""))
        skill = max(names, key=len) if names else ""
        emit(tag + ": input_match names an existing skill folder", "yes", "yes" if skill in skill_dirs else "no (%s)" % (skill or "none"))
        lo = int(g["min"]) if re.fullmatch(r"\d+", str(g.get("min", ""))) else 1
        hi = int(g["max"]) if re.fullmatch(r"\d+", str(g.get("max", ""))) else None
        tool_graders.setdefault(skill, []).append((lo, hi))
    if gtype == "regex":
        emit(tag + ": pattern is not empty", "yes", "yes" if g.get("pattern") else "no")
        emit(tag + ": target is documented", "yes", "yes" if g.get("target", "last_message") in REGEX_TARGETS else "no")

# --- case.yaml (optional) ---
case_yaml = os.path.join(case_dir, "case.yaml")
if os.path.isfile(case_yaml):
    top, nested, section, bad_yaml = {}, {}, None, []
    for line in read(case_yaml).split("\n"):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if line.startswith((" ", "\t")):
            match = re.match(r"^\s+([A-Za-z_][A-Za-z0-9_]*):\s+(.*)$", line)
            if match and section:
                nested.setdefault(section, {})[match.group(1)] = unquote(match.group(2))
            else:
                bad_yaml.append(line.strip())
            continue
        match = re.match(r"^([A-Za-z_][A-Za-z0-9_]*):(?:\s+(.*))?$", line)
        if not match:
            bad_yaml.append(line.strip())
            continue
        section = match.group(1)
        top[section] = unquote(match.group(2) or "")
    emit("case.yaml parses", "none", ",".join(bad_yaml) or "none")
    emit("case.yaml top-level keys", "context,name,schema_version", ",".join(sorted(top)))
    emit("case.yaml schema_version", "1.1", top.get("schema_version", "-"))
    emit("case.yaml name equals the folder", case, top.get("name", "-"))
    emit("case.yaml context keys", "scaffold_script", ",".join(sorted(nested.get("context", {}))) or "none")
    script = os.path.join(case_dir, nested.get("context", {}).get("scaffold_script", "scaffold.sh"))
    emit("scaffold script exists", "yes", "yes" if os.path.isfile(script) else "no")
    emit("scaffold script is executable", "yes", "yes" if os.access(script, os.X_OK) else "no")
    has_set = os.path.isfile(script) and any(l.strip() == "set -eu" for l in read(script).split("\n"))
    emit("scaffold script holds a set -eu line", "yes", "yes" if has_set else "no")

# --- the pinned ROADMAP criterion 5 case ---
if case == "write-to-client":
    emit("write-to-client: dossier-draft grader requires at least one call", "[(1, None)]", str(tool_graders.get("dossier-draft")))
    emit("write-to-client: dossier-ingest grader forbids every call", "[(0, 0)]", str(tool_graders.get("dossier-ingest")))
    emit("write-to-client: exactly two tool_used graders", "2", str(sum(len(v) for v in tool_graders.values())))
PY
)" || CHECKS_STATUS=$?
  assert_eq 0 "$CHECKS_STATUS" "$c: the shape checks ran"
  if [ "$CHECKS_STATUS" -ne 0 ]; then
    printf '%s\n' "$CHECKS" >&2
    continue
  fi
  while IFS=$'\t' read -r label expected actual; do
    [ -n "$label" ] || continue
    assert_eq "$expected" "$actual" "$c: $label"
  done <<EOF
$CHECKS
EOF
done

# --- every scaffold runs for free in a fresh workspace, minimal environment ---
# (cd "$ws" && env -i ...) is what `claude plugin eval --scaffold` documents:
# an empty workspace, a minimal environment, exit 0 required.
run_scaffold() {
  # run_scaffold CASE -> sets SC_WS, SC_HOME, SC_STATUS
  SC_WS="$(mktemp -d)"
  SC_HOME="$(mktemp -d)"
  SC_STATUS=0
  (cd "$SC_WS" && env -i PATH="$PATH" HOME="$SC_HOME" TMPDIR="${TMPDIR:-/tmp}" TERM=dumb \
    bash "$CASES_DIR/$1/scaffold.sh") >/dev/null 2>&1 || SC_STATUS=$?
}

cleanup_scaffold() {
  rm -rf "$SC_WS" "$SC_HOME"
}

SEEDED_CASES='call-prepare deal-status draft-reply ingest-transcript write-to-client'
for c in $EXPECTED_CASES; do
  case " $SEEDED_CASES " in
    *" $c "*)
      run_scaffold "$c"
      assert_eq 0 "$SC_STATUS" "$c: the scaffold exits 0"
      assert_file "$SC_WS/dossier.yaml"
      assert_eq 1 "$(git -C "$SC_WS" rev-list --count HEAD 2>/dev/null || echo none)" "$c: the seed is one commit"
      assert_lint "$SC_WS" 0 "$c: the seeded dossier is lint-clean"
      if [ "$c" = ingest-transcript ]; then
        # the transcript sits beside the dossier, written after the seed commit
        assert_eq '?? call-2026-10-10.txt' "$(git -C "$SC_WS" status --porcelain 2>/dev/null)" "$c: the transcript is the only untracked file"
        assert_eq 4 "$(wc -l < "$SC_WS/call-2026-10-10.txt" | tr -d ' ')" "$c: the transcript has four lines"
      fi
      cleanup_scaffold
      ;;
  esac
done

# init-new-client: a bare repository, no dossier yet (the skill under test creates it)
case " $EXPECTED_CASES " in
  *" init-new-client "*)
    run_scaffold init-new-client
    assert_eq 0 "$SC_STATUS" 'init-new-client: the scaffold exits 0'
    assert_dir "$SC_WS/.git"
    if [ -e "$SC_WS/dossier.yaml" ]; then
      echo 'FAIL: init-new-client: the scaffold must not seed a dossier.yaml' >&2
      TESTS_FAILED=$((TESTS_FAILED + 1))
    else
      TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
    cleanup_scaffold
    ;;
esac

# --- evals/results/ (run artefacts) is ignored ---
assert_grep '^evals/results/$' "$REPO_ROOT/.gitignore"

finish
