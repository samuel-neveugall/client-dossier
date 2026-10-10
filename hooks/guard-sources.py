#!/usr/bin/env python3
"""PreToolUse guard on a dossier's sources/ folder.

Mechanics tier only (spec principle: "hooks carry reminders"). Claude Code
runs this script before Write, Edit, MultiEdit, NotebookEdit and Bash calls
and feeds it one JSON object on stdin. When the target resolves under the
`sources/` folder of the nearest dossier, the script prints one deny decision
carrying the spec sentence "sources are immutable; file a correction in the
dossier instead" (PROTO-05). Every write under sources/ is denied, new files
included (D-03). A Bash command that visibly modifies an existing file there
is denied too, by a heuristic that is not the boundary: the skill's rule is
(D-04).

The dossier root is searched upward from the TARGET path, not from the
session cwd, with the very same find_root as scripts/lint.py (PROTO-08), so a
session started above a nested dossier still protects that dossier's sources/
and the nearest dossier wins.

It is read-only and fails open: any error, malformed stdin or missing field
gives exit 0 with no output at all, so a broken guard never blocks a write in
the many repositories where the plugin is enabled. It never prints an allow
decision (that would bypass the user's own permission rules); a silent run
leaves Claude Code's normal permission flow in charge.

Python 3 standard library only, targeting Python >= 3.8.
"""

import json
import os
import shlex
import sys
from pathlib import Path

CONFIG_NAME = "dossier.yaml"
SOURCES_DIR = "sources"
MESSAGE = "sources are immutable; file a correction in the dossier instead"

WRITE_TOOLS = ("Write", "Edit", "MultiEdit", "NotebookEdit")


def find_root(start):
    """The nearest directory at or above `start` holding dossier.yaml.

    No stop condition (D-01, Q-4): a dossier legitimately lives inside a
    larger repository, so the walk does not stop at `.git`. Returns None
    when no dossier.yaml exists anywhere up to the filesystem root.
    """
    here = Path(os.path.realpath(start))
    if not here.is_dir():
        here = here.parent
    for candidate in (here,) + tuple(here.parents):
        if os.path.isfile(os.path.join(str(candidate), CONFIG_NAME)):
            return str(candidate)
    return None


def under_any_sources(candidate):
    """The path of `candidate` relative to an ancestor dossier root when it
    lies under that root's sources/ folder, else None.

    EVERY ancestor holding a dossier.yaml is tried, not only the nearest: a
    dossier.yaml planted or received under sources/ would otherwise turn that
    subtree into a root and let its files through (A-F1). Nesting stays
    legitimate outside sources/, since the inner root's own sources/ is under
    the outer root's non-sources folder and is still denied by the inner root.
    The first component is compared casefolded because a case-insensitive
    filesystem keeps the spelling that was typed.
    """
    here = os.path.dirname(candidate)
    for ancestor in (here,) + tuple(Path(here).parents):
        ancestor = str(ancestor)
        if not os.path.isfile(os.path.join(ancestor, CONFIG_NAME)):
            continue
        parts = os.path.relpath(candidate, ancestor).split(os.sep)
        if parts[0] not in (".", "..") and parts[0].casefold() == SOURCES_DIR:
            return "/".join(parts)
    return None


def sources_target(path, cwd):
    """The path of `path` relative to its dossier root when it lies under
    that dossier's sources/ folder, else None.

    The path is joined to `cwd` (an absolute path stays absolute) and judged
    twice: resolved through symlinks and `..`, and lexically (`normpath`, no
    link followed). The lexical reading catches a sources/ folder that is
    itself a symlink to somewhere outside the dossier (R-F1, A-F4), where the
    resolved path has left the dossier. Either reading under a sources/ denies.
    """
    lexical = os.path.normpath(os.path.join(cwd, path))
    return under_any_sources(os.path.realpath(lexical)) or under_any_sources(lexical)


# ---------------------------------------------------------------------------
# THE BASH HEURISTIC (D-04)
# ---------------------------------------------------------------------------
#
# The command is tokenized with shlex, never executed or evaluated. It is cut
# into segments at the shell's separators, the effective working directory is
# followed through `cd` (and kept inside a subshell), and the verbs that
# visibly modify an EXISTING file under sources/ are looked for. A new file is
# let in. Anything the tokens do not show (interpreters, xargs, find -exec,
# editors, variables, command substitution) is allowed: the skill's rule is
# the boundary, this only catches the likely shortcut.

PUNCT = "();<>|&\n"
OPERATORS = ("&>>", "<<<", "&>", ">>", ">&", "<&", ">|", "<<", "&&", "||",
             "|&", ";;", "<(", ">(")
SEPARATORS = frozenset((";", ";;", "&&", "||", "|", "|&", "&", "\n"))
OPENERS = frozenset(("(", "<(", ">("))
WRITE_REDIRECTS = frozenset((">", ">>", ">|", "&>", "&>>"))
OTHER_REDIRECTS = frozenset(("<", "<<", "<<<", "<&", ">&"))
WRAPPERS = ("sudo", "command", "env", "nohup", "time", "exec")
WRAPPER_ARG_OPTIONS = {"sudo": ("-u", "-g", "-h", "-p", "-C", "-D", "-r",
                                "-t", "-T", "-U", "-R"),
                       "env": ("-u", "-C", "-S")}
SHELLS = ("bash", "sh", "zsh", "dash", "ksh")
MAX_SHELL_DEPTH = 2


def is_assignment(word):
    """True for a leading `NAME=value` word."""
    name, equals, _ = word.partition("=")
    return bool(equals) and name.isidentifier()


def has_in_place_flag(arg):
    """True for a perl or ruby flag cluster holding `i` (-i, -pi, -i.bak).
    The scan stops at `e`: what follows is the program text."""
    for char in arg[1:]:
        if char == "i":
            return True
        if char in "eE" or not char.isalnum():
            return False
    return False


def tokenize(command):
    """The command as a flat list of words and operators, or None when shlex
    cannot parse it (an unbalanced quote): the command is then allowed."""
    try:
        lex = shlex.shlex(command, posix=True, punctuation_chars=PUNCT)
        lex.whitespace = " \t\r"
        lex.whitespace_split = True
        lex.commenters = ""
        tokens = list(lex)
    except ValueError:
        return None
    flat = []
    for token in tokens:
        if token and all(ch in PUNCT for ch in token):
            index = 0
            while index < len(token):
                for operator in OPERATORS:
                    if token.startswith(operator, index):
                        flat.append(operator)
                        index += len(operator)
                        break
                else:
                    flat.append(token[index])
                    index += 1
        else:
            flat.append(token)
    return flat


def operand_path(operand, cwd):
    """The absolute path an operand names, or None when it cannot be known
    (empty, a variable or a substitution, or relative to an unknown cwd)."""
    if not operand or "$" in operand or "`" in operand:
        return None
    if operand.startswith("~"):
        operand = os.path.expanduser(operand)
    if os.path.isabs(operand):
        return operand
    if cwd is None:
        return None
    return os.path.join(cwd, operand)


def under_sources(operand, cwd):
    """The root-relative path when the operand lies under sources/."""
    path = operand_path(operand, cwd)
    if path is None:
        return None
    return sources_target(path, "/")


def existing_source_file(operand, cwd):
    """The root-relative path when the operand is an existing FILE under
    sources/ (a new file is not a modification)."""
    path = operand_path(operand, cwd)
    if path is None or not os.path.isfile(os.path.realpath(path)):
        return None
    return sources_target(path, "/")


def destination_hit(dest, sources, cwd):
    """A copy or move onto an existing source file: DEST is that file, or an
    existing directory already holding a file named like one of SOURCES."""
    path = operand_path(dest, cwd)
    if path is None:
        return None
    real = os.path.realpath(path)
    if os.path.isdir(real):
        for source in sources:
            base = os.path.basename(source.rstrip("/"))
            if base and "$" not in base and "`" not in base:
                hit = existing_source_file(os.path.join(real, base), "/")
                if hit:
                    return hit
        return None
    return existing_source_file(real, "/")


def split_args(args, arg_options=()):
    """(operands, option values). Options are skipped; the ones named in
    `arg_options` take the next word (or `--name=value`) as their value."""
    operands = []
    values = {}
    index = 0
    options_over = False
    while index < len(args):
        arg = args[index]
        index += 1
        if options_over or arg == "-" or not arg.startswith("-"):
            operands.append(arg)
        elif arg == "--":
            options_over = True
        elif arg in arg_options and index < len(args):
            values[arg] = args[index]
            index += 1
        elif arg.startswith("--") and arg.split("=")[0] in arg_options:
            values[arg.split("=")[0]] = arg.partition("=")[2]
    return operands, values


def first_hit(operands, cwd, finder=under_sources):
    for operand in operands:
        hit = finder(operand, cwd)
        if hit:
            return hit
    return None


def hit_sed(args, cwd):
    in_place = False
    script_given = False
    operands = []
    index = 0
    while index < len(args):
        arg = args[index]
        index += 1
        if arg == "--":
            operands.extend(args[index:])
            break
        if arg in ("-e", "-f", "--expression", "--file"):
            script_given = True
            index += 1
        elif arg.startswith(("--expression=", "--file=")):
            script_given = True
        elif arg.startswith("--in-place"):
            in_place = True
        elif arg.startswith("--") or arg == "-":
            if arg == "-":
                operands.append(arg)
        elif arg.startswith("-"):
            if "i" in arg:
                in_place = True
                # BSD sed: the suffix is the next word, possibly empty.
                if arg.endswith("i") and index < len(args) and args[index] == "":
                    index += 1
            elif arg[-1] in "ef":
                script_given = True
                index += 1
        else:
            operands.append(arg)
    if not in_place:
        return None
    if not script_given and operands:
        operands = operands[1:]
    return first_hit(operands, cwd)


def hit_perl(args, cwd):
    """perl and ruby: -i (alone or in a cluster such as -pi) edits in place."""
    in_place = False
    program_given = False
    operands = []
    index = 0
    while index < len(args):
        arg = args[index]
        index += 1
        if arg == "--":
            operands.extend(args[index:])
            break
        if arg.startswith("-") and len(arg) > 1:
            if arg[1] not in "MmIdDVxC" and has_in_place_flag(arg):
                in_place = True
            if arg[-1] in "eE" and not arg.startswith("--"):
                program_given = True
                index += 1
        else:
            operands.append(arg)
    if not in_place:
        return None
    if not program_given and operands:
        operands = operands[1:]
    return first_hit(operands, cwd)


def hit_move(args, cwd, arg_options):
    """mv: a source under sources/, or a destination that is an existing file."""
    operands, values = split_args(args, arg_options)
    target = values.get("-t") or values.get("--target-directory")
    if target is not None:
        sources, dest = operands, target
    elif len(operands) >= 2:
        sources, dest = operands[:-1], operands[-1]
    else:
        return None
    return first_hit(sources, cwd) or destination_hit(dest, sources, cwd)


def hit_copy(args, cwd, arg_options):
    """cp, install, rsync: only the destination counts; reading never does."""
    operands, values = split_args(args, arg_options)
    target = values.get("-t") or values.get("--target-directory")
    if target is not None:
        sources, dest = operands, target
    elif len(operands) >= 2:
        sources, dest = operands[:-1], operands[-1]
    else:
        return None
    return destination_hit(dest, sources, cwd)


def hit_git(args, cwd):
    index = 0
    while index < len(args):
        arg = args[index]
        if arg == "-C" and index + 1 < len(args):
            path = operand_path(args[index + 1], cwd)
            cwd = os.path.realpath(path) if path else None
            index += 2
        elif arg in ("-c", "--git-dir", "--work-tree", "--namespace"):
            index += 2
        elif arg.startswith("-"):
            index += 1
        else:
            break
    if index >= len(args):
        return None
    operands, _ = split_args(args[index + 1:])
    if args[index] == "rm":
        return first_hit(operands, cwd)
    if args[index] == "mv":
        return first_hit(operands[:-1], cwd)
    return None


def hit_shell(args, cwd, depth):
    """bash -c STRING: look into the string once more, with the same cwd."""
    if depth >= MAX_SHELL_DEPTH:
        return None
    index = 0
    while index < len(args):
        arg = args[index]
        index += 1
        if arg in ("-o", "-O", "--rcfile", "--init-file"):
            index += 1
        elif arg.startswith("-") and not arg.startswith("--") and "c" in arg:
            if index < len(args):
                return scan(args[index], cwd, depth + 1)
            return None
        elif not arg.startswith("-"):
            return None
    return None


def hit_verb(verb, args, cwd, depth):
    if verb == "sed":
        return hit_sed(args, cwd)
    if verb in ("perl", "ruby"):
        return hit_perl(args, cwd)
    if verb in ("rm", "unlink"):
        return first_hit(split_args(args)[0], cwd)
    if verb == "shred":
        return first_hit(split_args(args, ("-n", "--iterations", "-s", "--size"))[0], cwd)
    if verb == "truncate":
        return first_hit(split_args(args, ("-s", "--size", "-r", "--reference"))[0], cwd)
    if verb == "mv":
        return hit_move(args, cwd, ("-t", "--target-directory", "-S", "--suffix"))
    if verb == "cp":
        return hit_copy(args, cwd, ("-t", "--target-directory", "-S", "--suffix"))
    if verb == "install":
        if "-d" in args or "--directory" in args:
            return None
        return hit_copy(args, cwd, ("-t", "--target-directory", "-m", "--mode",
                                    "-o", "--owner", "-g", "--group", "-S", "--suffix"))
    if verb == "rsync":
        return hit_copy(args, cwd, ("-e", "--rsh", "--exclude", "--include", "--filter",
                                    "-f", "--exclude-from", "--include-from",
                                    "--files-from", "--rsync-path", "--temp-dir", "-T"))
    if verb == "git":
        return hit_git(args, cwd)
    if verb == "tee":
        return first_hit(split_args(args)[0], cwd, existing_source_file)
    if verb == "dd":
        return first_hit([a[3:] for a in args if a.startswith("of=")], cwd,
                         existing_source_file)
    if verb in SHELLS:
        return hit_shell(args, cwd, depth)
    return None


def strip_prefix(words):
    """The words from the real command on: leading NAME=value assignments and
    the sudo, command, env family dropped, with their own options."""
    index = 0
    while index < len(words):
        word = words[index]
        base = os.path.basename(word)
        if is_assignment(word):
            index += 1
        elif base in WRAPPERS:
            index += 1
            while index < len(words) and words[index].startswith("-") and words[index] != "--":
                takes_value = words[index] in WRAPPER_ARG_OPTIONS.get(base, ())
                index += 2 if takes_value else 1
        else:
            break
    return words[index:]


def change_dir(args, cwd):
    """The working directory after `cd ARGS`, None when it cannot be known."""
    operands = [a for a in args if a == "-" or not a.startswith("-")]
    target = operands[0] if operands else "~"
    if target == "-" or "$" in target or "`" in target:
        return None
    path = operand_path(target, cwd)
    return os.path.realpath(path) if path else None


def run_segment(words, targets, cwd, depth):
    """(hit, working directory after the segment) for one simple command."""
    for target in targets:
        hit = existing_source_file(target, cwd)
        if hit:
            return hit, cwd
    command = strip_prefix(words)
    if not command:
        return None, cwd
    verb = os.path.basename(command[0])
    if verb in ("cd", "pushd"):
        return None, change_dir(command[1:], cwd)
    if verb == "popd":
        return None, None
    return hit_verb(verb, command[1:], cwd, depth), cwd


def scan(command, cwd, depth):
    flat = tokenize(command)
    if flat is None:
        return None
    stack = []
    words = []
    targets = []
    index = 0
    while index <= len(flat):
        token = flat[index] if index < len(flat) else "\n"
        index += 1
        if token in WRITE_REDIRECTS or token in OTHER_REDIRECTS:
            nxt = flat[index] if index < len(flat) else None
            if nxt is not None and nxt not in SEPARATORS and nxt not in OPENERS \
                    and nxt != ")":
                if token in WRITE_REDIRECTS:
                    targets.append(nxt)
                index += 1
        elif token in SEPARATORS or token in OPENERS or token == ")":
            hit, cwd = run_segment(words, targets, cwd, depth)
            words = []
            targets = []
            if hit:
                return hit
            if token in OPENERS:
                stack.append(cwd)
            elif token == ")" and stack:
                cwd = stack.pop()
        else:
            words.append(token)
    return None


def bash_hit(command, cwd):
    """The root-relative path of an existing source file that `command`
    appears to modify, else None."""
    return scan(command, os.path.realpath(cwd), 0)


def main():
    data = json.load(sys.stdin)
    if not isinstance(data, dict):
        return
    cwd = data.get("cwd") or os.getcwd()
    tool = data.get("tool_name")
    tool_input = data.get("tool_input") or {}
    if not isinstance(tool_input, dict):
        return
    hit = None
    note = ""
    if tool in WRITE_TOOLS:
        path = tool_input.get("file_path") or tool_input.get("notebook_path")
        if isinstance(path, str) and path:
            hit = sources_target(path, cwd)
    elif tool == "Bash":
        command = tool_input.get("command")
        if isinstance(command, str) and command:
            hit = bash_hit(command, cwd)
            note = " (heuristic guard: this Bash command appears to modify it)"
    if hit:
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": MESSAGE + ": " + hit + note,
        }}))


if __name__ == "__main__":
    try:
        main()
    except Exception:  # fail open: a broken guard must never block a write
        pass
    sys.exit(0)
