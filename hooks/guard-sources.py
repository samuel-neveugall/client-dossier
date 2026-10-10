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

A target is under sources/ when it lies below the sources/ folder of ANY
directory above it that holds a dossier.yaml, not only the nearest one
(under_any_sources, PROTO-08). Searching from the TARGET path, not from the
session cwd, keeps a nested dossier protected when the session starts above
it, and trying every ancestor stops a dossier.yaml planted under sources/ from
turning that subtree into a root (A-F1). `find_root` below, byte-identical to
the one in scripts/lint.py, is no longer called by this guard: it stays only
because tests/test-hooks-config.sh asserts that every hook carries that very
function, and the nearest-root rule it states still holds for the linter.

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
# The hook is a one-shot process, so the filesystem answers are memoised: a
# command repeating the same operand a hundred thousand times costs one lookup,
# and a command naming a hundred thousand distinct files in one directory
# costs one directory resolution plus one lstat each.
TARGET_CACHE = {}
FILE_CACHE = {}
ROOT_CACHE = {}
DIR_CACHE = {}
BASE_CACHE = {}
MOVE_CACHE = {}


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


def is_root(directory):
    """True when `directory` holds a dossier.yaml (memoised)."""
    if directory not in ROOT_CACHE:
        ROOT_CACHE[directory] = os.path.isfile(os.path.join(directory, CONFIG_NAME))
    return ROOT_CACHE[directory]


def under_any_sources(candidate):
    """The path of `candidate` relative to an ancestor dossier root when it
    lies under that root's sources/ folder, else None.

    `candidate` is absolute and normalised. EVERY ancestor holding a
    dossier.yaml is tried, not only the nearest: a dossier.yaml planted or
    received under sources/ would otherwise turn that subtree into a root and
    let its files through (A-F1). Nesting stays legitimate outside sources/,
    since the inner root's own sources/ is under the outer root's non-sources
    folder and is still denied by the inner root. The first component is
    compared casefolded because a case-insensitive filesystem keeps the
    spelling that was typed.
    """
    end = len(candidate)
    while True:
        cut = candidate.rfind("/", 0, end)
        if cut < 0:
            return None
        if is_root(candidate[:cut] or "/"):
            rest = candidate[cut + 1:]
            if rest.split("/", 1)[0].casefold() == SOURCES_DIR:
                return rest
        end = cut


def real_path(path):
    """os.path.realpath with the directory part memoised: only the last
    component is looked at (one lstat) when the directory was seen before."""
    head, tail = os.path.split(path)
    if not tail or not head:
        return os.path.realpath(path)
    if head not in DIR_CACHE:
        DIR_CACHE[head] = os.path.realpath(head)
    joined = os.path.join(DIR_CACHE[head], tail)
    return os.path.realpath(joined) if os.path.islink(joined) else joined


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
    if lexical not in TARGET_CACHE:
        TARGET_CACHE[lexical] = under_any_sources(real_path(lexical)) \
            or under_any_sources(lexical)
    return TARGET_CACHE[lexical]


# ---------------------------------------------------------------------------
# THE BASH HEURISTIC (D-04)
# ---------------------------------------------------------------------------
#
# The command is tokenized with shlex (heredoc bodies removed first, then
# comments, line continuations, ANSI-C and stray quotes by prepare(), a lenient
# per-line fallback on a parse error), never executed or evaluated. Its cost
# is linear in its size and bounded (MAX_* below). It is cut into segments at
# the shell's separators, the effective working directory is followed through
# `cd`, `cd -`, `pushd` and `popd` (and kept inside a subshell), and the verbs
# that visibly modify an EXISTING file under sources/ are looked for, as well
# as the rm or mv of a dossier root and the globs and braces that can name a
# sources/ folder. A new file is let in. Anything the tokens do not show
# (eval, interpreters, xargs, find -exec, command substitution, variables,
# loops over globs) is allowed: this is the accepted debt D-04 (restated by
# D-17), the skill's rule is the boundary, and this only catches the likely
# shortcut.

PUNCT = "();<>|&\n"
OPERATORS = ("&>>", "<<<", "&>", ">>", ">&", "<&", ">|", "<<", "&&", "||",
             "|&", ";;", "<(", ">(")
SEPARATORS = frozenset((";", ";;", "&&", "||", "|", "|&", "&", "\n"))
OPENERS = frozenset(("(", "<(", ">("))
WRITE_REDIRECTS = frozenset((">", ">>", ">|", "&>", "&>>"))
OTHER_REDIRECTS = frozenset(("<", "<<", "<<<", "<&", ">&"))
WRAPPERS = ("sudo", "command", "env", "nohup", "time", "exec", "builtin",
            "timeout", "nice", "ionice", "stdbuf", "caffeinate")
# Wrappers that may carry a numeric word (a duration, a niceness) before the
# real command.
NUMERIC_WRAPPERS = ("timeout", "nice", "ionice", "stdbuf", "caffeinate")
# Shell reserved words that can open a segment: the real command follows.
RESERVED = frozenset(("if", "then", "else", "elif", "fi", "do", "done", "while",
                      "until", "for", "case", "esac", "{", "}", "!", "function"))
WRAPPER_ARG_OPTIONS = {"sudo": ("-u", "-g", "-h", "-p", "-C", "-D", "-r",
                                "-t", "-T", "-U", "-R"),
                       "env": ("-u", "-C", "-S"),
                       "timeout": ("-s", "--signal", "-k", "--kill-after"),
                       "nice": ("-n", "--adjustment"),
                       "ionice": ("-c", "--class", "-n", "--classdata", "-p", "--pid",
                                  "-P", "--pgid", "-u", "--uid"),
                       "stdbuf": ("-i", "--input", "-o", "--output", "-e", "--error"),
                       "caffeinate": ("-t", "-w")}
SHELLS = ("bash", "sh", "zsh", "dash", "ksh")
# Commands that run their stdin as shell text: a heredoc body they read is code.
SHELL_READERS = SHELLS + ("source", ".")
MAX_SHELL_DEPTH = 2
# Bounds that keep the cost linear on a pathological command (NF-6): a
# terminator or delimiter word, one word handed to shlex (which is quadratic
# on a single huge word), the command size above which heredoc stripping is
# given up for a raw scan, and the heredoc operators read on one line.
MAX_WORD = 256
MAX_TOKEN = 65536
MAX_STRIP = 524288
MAX_PUNCT = 4096
MAX_OPERATORS = 64
# Bounds that keep the cost low on a deliberately huge command (F3): an
# operand longer than MAX_OPERAND is not a path, the operands judged in one
# segment and in the whole command are capped, and so are the expansions of a
# brace or a glob. Past a bound the guard stops resolving and only refuses what
# shows a `sources` path component in the text: a pathological command is
# let through unless it names sources/ in plain sight.
MAX_OPERAND = 4096
MAX_OPERANDS = 512
MAX_JUDGED = 4096
MAX_EXPANSION = 64
MAX_LISTING = 50000
MAX_PILE = 64
JUDGED = [0]


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


def is_number(word):
    """True for a count or a duration: 10, 1.5, 5s, 2m, 1h, 1d."""
    digits = word[:-1] if word[-1:] in ("s", "m", "h", "d") else word
    return digits.replace(".", "", 1).isdigit()


def is_fd_operand(word):
    """True for the operand of `>&` that duplicates a descriptor: N, N- or -."""
    return word == "-" or word.rstrip("-").isdigit()


def heredoc_operators(line, quote=""):
    """([(start, dash, word, quoted, end)], quote) for each `<<WORD`,
    `<<-WORD`, `<<'WORD'`, `<<"WORD"` or `<<\\WORD` of `line` that bash would
    read as a heredoc (a here-string `<<<` is not one), and the quote still
    open at the end of the line. `quote` is the one open at its start: a
    string that spans lines carries its state to the next one (F2).

    The line is walked once with the state that decides it: inside quotes, a
    `<<` is text; so it is inside `$((...))` / `((...))` (a shift), inside
    `[[ ... ]]`, and after a `#` that starts a comment (NF-3). Every doubt
    resolves to "not a heredoc": the lines that follow are then scanned as
    commands, which can only add a false positive, never hide a command.
    """
    found = []
    size = len(line)
    index = 0
    arith = brackets = 0
    prev = " "
    while index < size:
        char = line[index]
        if quote:
            if char == "\\" and quote != "'":
                index += 2
                continue
            if char == quote[-1]:
                quote = ""
            index += 1
            continue
        if char == "\\":
            index += 2
            prev = "x"
            continue
        if char in "'\"":
            quote = "$'" if char == "'" and prev == "$" else char
        elif char == "#" and prev in " \t;&|()":
            break
        elif line.startswith("((", index):
            arith += 1
            index += 2
            prev = "("
            continue
        elif line.startswith("))", index) and arith:
            arith -= 1
            index += 2
            prev = ")"
            continue
        elif line.startswith("[[", index) and prev in " \t;&|(":
            brackets += 1
            index += 2
            prev = "["
            continue
        elif line.startswith("]]", index) and brackets:
            brackets -= 1
            index += 2
            prev = "]"
            continue
        elif char == "<" and line.startswith("<<", index):
            if line.startswith("<", index + 2):
                index += 3  # here-string
                prev = "<"
                continue
            if arith or brackets:
                index += 2
                prev = "<"
                continue
            end = index + 2
            dash = line.startswith("-", end)
            end += 1 if dash else 0
            while line.startswith((" ", "\t"), end):
                end += 1
            escaped = line.startswith("\\", end)
            end += 1 if escaped else 0
            opener = line[end] if line[end:end + 1] in ("'", '"') else ""
            end += 1 if opener else 0
            start = end
            while end < size and (line[end].isalnum() or line[end] == "_") \
                    and line[end].isascii():
                end += 1
            word = line[start:end]
            if word and not word[0].isdigit() and len(word) <= MAX_WORD \
                    and line[end:end + len(opener)] == opener:
                end += len(opener)
                found.append((index, dash, word, bool(opener or escaped), end))
            index = max(end, index + 2)
            prev = "<"
            continue
        prev = char
        index += 1
    return found, quote


def command_verb(text):
    """The basename of the command that `text` (what precedes a point of a
    line) ends in: the words after the last separator, wrappers and leading
    assignments dropped. Only the last few thousand characters are read."""
    cut = max(text.rfind(sep) for sep in ";|&(`{")
    words = [word.strip("'\"") for word in text[max(cut + 1, len(text) - 4096):].split()]
    words = strip_prefix(words)
    return os.path.basename(words[0]) if words else ""


def feeds_shell(line, start, end):
    """True when the heredoc whose operator spans line[start:end] is read by a
    shell: `bash <<EOF`, `sh -s <<'EOF'`, `source /dev/stdin <<EOF`, or
    `cat <<'EOF' | bash`. Its body is then commands, not text (NF-2)."""
    if command_verb(line[:start]) in SHELL_READERS:
        return True
    for piece in line[end:end + 4096].split("|")[1:]:
        if command_verb(" " + piece) in SHELL_READERS:
            return True
    return False


def substitutions(body):
    """The `$(...)` and backtick spans of a heredoc body, as lines. In an
    unquoted heredoc the shell runs them even when the verb is `cat`. An
    unclosed span is taken to the end of the body (the safe direction)."""
    spans = []
    index = 0
    while True:
        dollar = body.find("$(", index)
        tick = body.find("`", index)
        if dollar == -1 and tick == -1:
            return spans
        if tick == -1 or (dollar != -1 and dollar < tick):
            depth = 1
            cursor = dollar + 2
            while cursor < len(body) and depth:
                char = body[cursor]
                depth += 1 if char == "(" else -1 if char == ")" else 0
                cursor += 1
            spans.append(body[dollar + 2:cursor - 1 if depth == 0 else cursor])
            index = cursor
        else:
            close = body.find("`", tick + 1)
            if close == -1:
                spans.append(body[tick + 1:])
                return spans
            spans.append(body[tick + 1:close])
            index = close + 1


def strip_heredocs(command, carry=True):
    """(the command without its heredoc bodies and terminator lines, True when
    a quote is still open at its end).

    A body is text, not commands: tokenising it gave a false positive (a
    `rm sources/x` quoted in the body) and a bypass (an apostrophe in the body
    broke shlex for the whole command). The `<<WORD` line itself stays. An
    operator inside quotes, one whose terminator never comes, or one beyond
    the first MAX_OPERATORS of its line is not a heredoc and nothing is
    dropped for it. Two bodies are NOT text and stay in the command (NF-2):
    one read by a shell (`bash <<EOF`, `... | sh`), and the `$(...)` and
    backtick spans of an unquoted one.

    One pass: the lines that could be a terminator are indexed once and each
    word keeps a cursor, so the cost stays linear in the size of the command
    (NF-6). With `carry`, the quote state is carried from line to line: a
    string spanning lines that holds `<<EOF` does not open a heredoc (F2). The
    caller reruns without it when a quote stays open to the end, which is the
    stray apostrophe of `echo it's`.
    """
    lines = command.split("\n")
    plain = {}
    dashed = {}
    for number, text in enumerate(lines):
        if len(text) <= MAX_WORD:
            plain.setdefault(text, []).append(number)
        bare = text.lstrip("\t")
        if len(bare) <= MAX_WORD:
            dashed.setdefault(bare, []).append(number)
    cursors = {}
    kept = []
    index = 0
    quote = ""
    while index < len(lines):
        line = lines[index]
        kept.append(line)
        index += 1
        if not quote and "<<" not in line and "'" not in line and '"' not in line:
            continue
        operators, quote = heredoc_operators(line, quote if carry else "")
        for start, dash, word, quoted, end in operators[:MAX_OPERATORS]:
            positions = (dashed if dash else plain).get(word)
            if not positions:
                continue
            cursor = cursors.get((dash, word), 0)
            while cursor < len(positions) and positions[cursor] < index:
                cursor += 1
            cursors[(dash, word)] = cursor
            if cursor == len(positions):
                continue
            body = lines[index:positions[cursor]]
            if feeds_shell(line, start, end):
                kept.extend(body)
            elif not quoted:
                kept.extend(substitutions("\n".join(body)))
            index = positions[cursor] + 1
    return "\n".join(kept), bool(quote)


def prepare(text):
    """`text` ready for shlex, in one linear pass (NF-1, NF-6).

    - A backslash-newline is removed (a line continuation), outside single
      quotes, so `rm \\<NL> sources/a` is one command. A comment ends at its
      newline whatever precedes it, and is dropped.
    - A quote that has no closing partner is replaced by a space: the one
      stray apostrophe of `echo it's; rm sources/a` then blinds nothing (A-F2).
    - A word longer than MAX_TOKEN characters, or a run of more than MAX_PUNCT
      operator characters, is cut there: shlex is quadratic on one huge token,
      and no path or real command is that long. (A quoted script longer than
      that, handed to `bash -c`, is therefore only read up to its first
      MAX_TOKEN characters: the guard is a heuristic, D-04.)
    """
    out = []
    size = len(text)
    index = 0
    run = 0
    punct = 0
    prev = "\n"
    while index < size:
        char = text[index]
        if char in "\\'\"#":
            punct = 0
        if char == "\\":
            follow = text[index + 1:index + 2]
            index += 2
            if follow and follow != "\n":
                # What follows a backslash is text, never the start of a
                # comment: `echo a\ #b` has no comment (F1).
                prev = "x"
                if run < MAX_TOKEN:
                    out.append(char + follow)
                    run += 2
        elif char == "'" and out and out[-1] == "$":
            # ANSI-C quotes $'...': a backslash escapes, `\'` does not close.
            cursor = index + 1
            while cursor < size and text[cursor] != "'":
                cursor += 2 if text[cursor] == "\\" else 1
            if cursor >= size:
                out.append(" ")
                index += 1
                run = 0
                prev = " "
            else:
                out.pop()
                body = text[index + 1:cursor].replace("'", "_")
                out.append("'" + body[:max(MAX_TOKEN - run, 0)] + "'")
                run += cursor - index + 1
                index = cursor + 1
                prev = "'"
        elif char == "'":
            close = text.find("'", index + 1)
            if close == -1:
                out.append(" ")
                index += 1
                run = 0
                prev = " "
            else:
                out.append("'" + text[index + 1:min(close, index + 1 + max(MAX_TOKEN - run, 0))] + "'")
                run += close - index + 1
                index = close + 1
                prev = "'"
        elif char == '"':
            cursor = index + 1
            body = []
            closed = False
            while cursor < size:
                inner = text[cursor]
                if inner == "\\":
                    follow = text[cursor + 1:cursor + 2]
                    cursor += 2
                    if follow and follow != "\n":
                        body.append(inner + follow)
                elif inner == '"':
                    closed = True
                    break
                else:
                    body.append(inner)
                    cursor += 1
            if closed:
                joined = "".join(body)
                out.append('"' + joined[:max(MAX_TOKEN - run, 0)] + '"')
                run += len(joined) + 2
                index = cursor + 1
                prev = '"'
            else:
                out.append(" ")
                index += 1
                run = 0
                prev = " "
        elif char == "#" and prev in " \t\n;&|()":
            newline = text.find("\n", index)
            index = size if newline == -1 else newline
        else:
            index += 1
            if char in PUNCT:
                run = 0
                if punct < MAX_PUNCT:
                    punct += 1
                    out.append(char)
            else:
                punct = 0
                if char in " \t\r":
                    run = 0
                    out.append(char)
                elif run < MAX_TOKEN:
                    run += 1
                    out.append(char)
            prev = char
    return "".join(out)


def lex(text):
    """shlex words of `text` split into words and operators, None on a
    parse error (an unbalanced quote)."""
    try:
        lexer = shlex.shlex(text, posix=True, punctuation_chars=PUNCT)
        lexer.whitespace = " \t\r"
        lexer.whitespace_split = True
        lexer.commenters = ""
        tokens = list(lexer)
    except ValueError:
        return None
    flat = []
    for token in tokens:
        if token and all(ch in PUNCT for ch in token):
            index = 0
            size = len(token)
            while index < size:
                for width in (3, 2):
                    if token[index:index + width] in OPERATORS:
                        flat.append(token[index:index + width])
                        index += width
                        break
                else:
                    flat.append(token[index])
                    index += 1
        else:
            flat.append(token)
    return flat


def lenient_lex(text):
    """The words of `text` when shlex still rejects it after prepare(): line
    by line, and a line that does not parse loses its quote characters."""
    flat = []
    for line in text.split("\n"):
        words = lex(line)
        if words is None:
            words = lex(line.replace("'", " ").replace('"', " ").replace("\\", " "))
        flat.extend(words or [])
        flat.append("\n")
    return flat


def tokenize(command):
    """The command as a flat list of words and operators: heredoc bodies
    removed first (unless the command is too big to be worth it, MAX_STRIP),
    then comments, line continuations and stray quotes by prepare(), then
    shlex, then the lenient fallback."""
    text = command
    if len(text) <= MAX_STRIP and "<<" in text:
        text, open_quote = strip_heredocs(text)
        if open_quote:
            text, _ = strip_heredocs(command, False)
    text = prepare(text)
    flat = lex(text)
    return flat if flat is not None else lenient_lex(text)


class GuessedCwd(str):
    """A working directory that is no longer known (after `cd -` with no
    OLDPWD, `cd $X`, `cd "$(...)"`, `cd` to a directory that is not there,
    `popd` on an empty stack): the string is the last one that was. A relative
    operand is then judged against that directory AND against the root of
    every dossier above it, so the guard errs toward a false positive instead
    of letting the command through (NF-5)."""


def guessed(cwd):
    return cwd if cwd is None or isinstance(cwd, GuessedCwd) else GuessedCwd(cwd)


def base_dirs(cwd):
    """The directories a relative operand may be relative to."""
    if cwd is None:
        return []
    key = (str(cwd), isinstance(cwd, GuessedCwd))
    if key not in BASE_CACHE:
        dirs = [str(cwd)]
        if key[1]:
            for ancestor in (Path(cwd),) + tuple(Path(cwd).parents):
                if is_root(str(ancestor)):
                    dirs.append(str(ancestor))
        BASE_CACHE[key] = dirs
    return BASE_CACHE[key]


def glob_match(pattern, name):
    """fnmatch.fnmatchcase without the import: `*`, `?`, `[set]`, `[!set]`,
    with ranges. Case is the caller's business."""
    p = n = 0
    star = mark = -1
    while n < len(name):
        step = 0
        if p < len(pattern):
            char = pattern[p]
            if char == "*":
                star, mark = p, n
                p += 1
                continue
            if char == "?":
                step = 1
            elif char == "[" and pattern.find("]", p + 2) != -1:
                close = pattern.find("]", p + 2)
                members = pattern[p + 1:close]
                negate = members[:1] in ("!", "^")
                members = members[1:] if negate else members
                found = False
                at = 0
                while at < len(members):
                    if at + 2 < len(members) and members[at + 1] == "-":
                        found = found or members[at] <= name[n] <= members[at + 2]
                        at += 3
                    else:
                        found = found or members[at] == name[n]
                        at += 1
                if found != negate:
                    p, n = close + 1, n + 1
                    continue
            elif char == name[n]:
                step = 1
            if step:
                p += 1
                n += 1
                continue
        if star < 0:
            return False
        mark += 1
        p, n = star + 1, mark
    while p < len(pattern) and pattern[p] == "*":
        p += 1
    return p == len(pattern)


def brace_group(item):
    """(start, commas, end) of the first `{a,b}` group of `item`, else None.
    Only the first few opening braces are tried: a brace with no comma
    (`{x}`, `{1..3}`) is literal."""
    start = -1
    for _ in range(8):
        start = item.find("{", start + 1)
        if start == -1:
            return None
        depth = 0
        commas = []
        for at in range(start, len(item)):
            char = item[at]
            if char == "{":
                depth += 1
            elif char == "}":
                depth -= 1
                if depth == 0:
                    if commas:
                        return start, commas, at
                    break
            elif char == "," and depth == 1:
                commas.append(at)
    return None


def brace_expand(word):
    """The words a `{a,b}` brace expansion of `word` gives, at most
    MAX_EXPANSION of them."""
    results = []
    pending = [word]
    while pending and len(results) + len(pending) <= MAX_EXPANSION:
        item = pending.pop(0)
        group = brace_group(item)
        if group is None:
            results.append(item)
            continue
        start, commas, end = group
        edges = [start] + commas + [end]
        for left, right in zip(edges, edges[1:]):
            pending.append(item[:start] + item[left + 1:right] + item[end + 1:])
    return results + pending


def spare(operand):
    """True when `operand` is not to be resolved: too long to be a path, or
    the budget of operands judged in this command is spent (F3)."""
    JUDGED[0] += 1
    return len(operand) > MAX_OPERAND or JUDGED[0] > MAX_JUDGED


def visible_sources(text):
    """The hit for an operand the guard gave up resolving: `sources` when one
    of its path components is `sources`, else None (the pathological command
    is let through unless it names sources/ in plain sight)."""
    for part in text.split("/"):
        if part.casefold() == SOURCES_DIR:
            return SOURCES_DIR
    return None


def glob_candidate(word, base):
    """The absolute path a word names from BASE. A glob component that can
    match an existing `sources` folder (`sour*`, `s?urces`, `[s]ources`, `*`)
    is read as `sources`: the shell would expand it to that folder."""
    parts = word.split("/")
    for at, part in enumerate(parts):
        if any(char in part for char in "*?[") and glob_match(part.casefold(), SOURCES_DIR):
            prefix = "/".join(parts[:at])
            folder = prefix if os.path.isabs(prefix) or not base else os.path.join(base, prefix)
            if os.path.isdir(os.path.join(folder or "/", SOURCES_DIR)):
                parts[at] = SOURCES_DIR
                break
    word = "/".join(parts)
    return word if os.path.isabs(word) else os.path.join(base, word)


def operand_paths(operand, cwd):
    """The absolute paths an operand may name: none when it cannot be known
    (empty, a variable or a substitution), several after an unknown `cd`, a
    brace expansion or a glob that can name a sources/ folder."""
    if not operand or "$" in operand or "`" in operand:
        return []
    words = brace_expand(operand) if "{" in operand else [operand]
    paths = []
    for word in words:
        if word.startswith("~"):
            word = os.path.expanduser(word)
        for base in ([""] if os.path.isabs(word) else base_dirs(cwd)):
            paths.append(glob_candidate(word, base))
    return paths


def under_sources(operand, cwd):
    """The root-relative path when the operand lies under sources/."""
    if spare(operand):
        return visible_sources(operand)
    for path in operand_paths(operand, cwd):
        hit = sources_target(path, "/")
        if hit:
            return hit
    return None


def existing_source_file(operand, cwd):
    """The root-relative path when the operand is an existing FILE under
    sources/ (a new file is not a modification)."""
    if spare(operand):
        return visible_sources(operand)
    for path in operand_paths(operand, cwd):
        if path not in FILE_CACHE:
            FILE_CACHE[path] = os.path.isfile(real_path(path))
        if FILE_CACHE[path]:
            hit = sources_target(path, "/")
            if hit:
                return hit
    return None


def holds_sources(path):
    """True when `path` is a dossier root that has a sources/ folder."""
    real = os.path.realpath(path)
    return is_root(real) and os.path.isdir(os.path.join(real, SOURCES_DIR))


def parent_hit(operand, cwd):
    """`sources` when removing or moving the operand takes a whole dossier
    with it: the operand is a dossier root (`.`, `../d`), or a glob that
    names one (`*`, `./*`). Only the directories typed or listed are looked
    at, not the ones below them."""
    if not operand or "$" in operand or "`" in operand or spare(operand):
        return None
    words = brace_expand(operand) if "{" in operand else [operand]
    for word in words:
        if word.startswith("~"):
            word = os.path.expanduser(word)
        for base in ([""] if os.path.isabs(word) else base_dirs(cwd)):
            full = os.path.normpath(os.path.join(base, word))
            head, tail = os.path.split(full)
            if any(char in tail for char in "*?["):
                try:
                    names = os.listdir(head)
                except OSError:
                    continue
                matched = 0
                for name in names[:MAX_LISTING]:
                    if glob_match(tail.casefold(), name.casefold()):
                        matched += 1
                        if matched > MAX_EXPANSION:
                            break
                        if holds_sources(os.path.join(head, name)):
                            return SOURCES_DIR
            elif holds_sources(full):
                return SOURCES_DIR
    return None


def removal_hit(operand, cwd):
    """An operand that rm or mv would take out of sources/: a file under it, or
    a dossier root holding it."""
    return under_sources(operand, cwd) or parent_hit(operand, cwd)


def destination_hit(dest, sources, cwd):
    """A copy or move onto an existing source file: DEST is that file, or an
    existing directory already holding a file named like one of SOURCES.
    DEST is judged as typed AND resolved (NF-4): through a sources/ symlink
    the resolved path has left the dossier, the typed one has not."""
    if spare(dest):
        return visible_sources(dest)
    for path in operand_paths(dest, cwd):
        for spelling in (path, os.path.realpath(path)):
            if os.path.isdir(spelling):
                for source in sources[:MAX_OPERANDS]:
                    base = os.path.basename(source.rstrip("/"))
                    if base and "$" not in base and "`" not in base:
                        hit = existing_source_file(os.path.join(spelling, base), "/")
                        if hit:
                            return hit
            else:
                hit = existing_source_file(spelling, "/")
                if hit:
                    return hit
    return None


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
    """The first hit among the operands. Only the first MAX_OPERANDS are
    resolved; past them the guard only refuses a visible `sources` component
    (F3)."""
    for number, operand in enumerate(operands):
        if number >= MAX_OPERANDS:
            for rest in operands[number:]:
                hit = visible_sources(rest)
                if hit:
                    return hit
            return None
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
    return first_hit(sources, cwd, removal_hit) or destination_hit(dest, sources, cwd)


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


def hit_link(args, cwd):
    """ln: an operand that is an existing source file. A hard link makes a
    second name that edits the same bytes; -f replaces the destination. A
    plain symbolic link is let in: writing through it is caught by the
    resolved path (A-F4)."""
    symbolic = forced = False
    for arg in args:
        if arg == "--":
            break
        if arg in ("--symbolic",):
            symbolic = True
        elif arg in ("--force",):
            forced = True
        elif arg.startswith("-") and not arg.startswith("--"):
            symbolic = symbolic or "s" in arg
            forced = forced or "f" in arg
    if symbolic and not forced:
        return None
    return first_hit(split_args(args, ("-t", "--target-directory", "-S", "--suffix"))[0],
                     cwd, existing_source_file)


def hit_git(args, cwd):
    index = 0
    while index < len(args):
        arg = args[index]
        if arg == "-C" and index + 1 < len(args):
            cwd = resolve_dir(args[index + 1], cwd)
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
        return first_hit(operands, cwd, removal_hit)
    if args[index] == "mv":
        return first_hit(operands[:-1], cwd, removal_hit)
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


def hit_patch(args, cwd):
    """patch: the file it edits (the first operand) or writes with -o. The
    files a diff names are not visible in the command."""
    if "--dry-run" in args or "-C" in args or "--check" in args:
        return None
    operands, values = split_args(args, (
        "-i", "--input", "-o", "--output", "-p", "--strip", "-d", "--directory",
        "-r", "--reject-file", "-D", "--ifdef", "-F", "--fuzz", "-B", "--prefix",
        "-Y", "--basename-prefix", "-z", "--suffix", "-V", "--version-control"))
    directory = values.get("-d") or values.get("--directory")
    if directory:
        cwd = resolve_dir(directory, cwd)
    outputs = [values[key] for key in ("-o", "--output") if key in values]
    return first_hit(operands[:1] + outputs, cwd, existing_source_file)


def hit_awk(args, cwd):
    """awk and gawk with the inplace extension (`-i inplace`)."""
    in_place = False
    for number, arg in enumerate(args):
        following = args[number + 1] if number + 1 < len(args) else ""
        if arg in ("-i", "--include") and following.startswith("inplace"):
            in_place = True
        elif arg.startswith(("-iinplace", "--include=inplace")) or \
                ("@include" in arg and "inplace" in arg):
            in_place = True
    if not in_place:
        return None
    operands = [arg for arg in args if not arg.startswith("-")]
    return first_hit(operands, cwd, existing_source_file)


def hit_editor(verb, args, cwd):
    """ed and ex (scripted line editors), vi and vim in their silent ex mode
    (`-es`): the file they are given is the one they write."""
    if verb in ("vi", "vim", "nvim"):
        flags = set("".join(a[1:] for a in args if a.startswith("-") and not a.startswith("--")))
        if "s" not in flags or not ("e" in flags or "E" in flags):
            return None
    return first_hit(split_args(args)[0], cwd, existing_source_file)


def hit_verb(verb, args, cwd, depth):
    if verb in ("sed", "gsed"):
        return hit_sed(args, cwd)
    if verb in ("perl", "ruby"):
        return hit_perl(args, cwd)
    if verb == "rm":
        return first_hit(split_args(args)[0], cwd, removal_hit)
    if verb == "unlink":
        return first_hit(split_args(args)[0], cwd)
    if verb == "patch":
        return hit_patch(args, cwd)
    if verb in ("awk", "gawk"):
        return hit_awk(args, cwd)
    if verb in ("ed", "ex", "vi", "vim", "nvim"):
        return hit_editor(verb, args, cwd)
    if verb == "sponge":
        return first_hit(split_args(args)[0], cwd, existing_source_file)
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
    if verb == "ln":
        return hit_link(args, cwd)
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
        if word == "function":
            index += 2  # the keyword and the name it defines
        elif is_assignment(word) or word in RESERVED:
            index += 1
        elif base in WRAPPERS:
            index += 1
            while index < len(words) and words[index].startswith("-") and words[index] != "--":
                takes_value = words[index] in WRAPPER_ARG_OPTIONS.get(base, ())
                index += 2 if takes_value else 1
            if base in NUMERIC_WRAPPERS and index < len(words) and is_number(words[index]):
                index += 1  # timeout's duration, caffeinate's seconds
        else:
            break
    return words[index:]


def resolve_dir(target, cwd):
    """The working directory after moving to TARGET from CWD: resolved when
    it can be known, else the last known one marked as guessed. A directory
    that is not there is not followed (the shell would not go there either):
    no realpath is spent on it, which keeps a chain of `cd` linear (F3)."""
    if cwd is None:
        return None
    if target == "-" or not target or "$" in target or "`" in target \
            or len(target) > MAX_OPERAND or any(char in target for char in "*?[{"):
        return guessed(cwd)
    absolute = target.startswith("~") or os.path.isabs(target)
    if not absolute and isinstance(cwd, GuessedCwd):
        return cwd
    key = (str(cwd), target)
    if key not in MOVE_CACHE:
        path = os.path.join(str(cwd), os.path.expanduser(target) if target[0] == "~" else target)
        MOVE_CACHE[key] = os.path.realpath(path) if os.path.isdir(path) else None
    return MOVE_CACHE[key] or guessed(cwd)


def move(verb, args, where):
    """The (working directory, OLDPWD, directory stack) after `cd`, `pushd` or
    `popd` ARGS: `cd -` returns to OLDPWD, `pushd` stacks the directory it
    leaves and `popd` returns to it (F4)."""
    cwd, old, pile = where
    operands = [a for a in args if a == "-" or not a.startswith("-")]
    target = operands[0] if operands else None
    if verb == "popd":
        if pile and not operands:
            return pile[0], cwd, pile[1:]
        return guessed(cwd), cwd, pile
    if verb == "pushd" and (target is None or target[0] == "+"):
        return guessed(cwd), cwd, pile
    if target == "-":
        new = old if old is not None else guessed(cwd)
    else:
        new = resolve_dir(target or "~", cwd)
    return new, cwd, (((cwd,) + pile)[:MAX_PILE] if verb == "pushd" else pile)


def run_segment(words, targets, where, depth):
    """(hit, where) for one simple command; `where` is the (working
    directory, OLDPWD, directory stack) triple."""
    hit = first_hit(targets, where[0], existing_source_file)
    if hit:
        return hit, where
    command = strip_prefix(words)
    if not command:
        return None, where
    verb = os.path.basename(command[0])
    if verb in ("cd", "pushd", "popd"):
        return None, move(verb, command[1:], where)
    return hit_verb(verb, command[1:], where[0], depth), where


def scan(command, cwd, depth):
    flat = tokenize(command)
    if flat is None:
        return None
    stack = []
    words = []
    targets = []
    where = (cwd, None, ())
    index = 0
    while index <= len(flat):
        token = flat[index] if index < len(flat) else "\n"
        index += 1
        if token in WRITE_REDIRECTS or token in OTHER_REDIRECTS:
            nxt = flat[index] if index < len(flat) else None
            if nxt is not None and nxt not in SEPARATORS and nxt not in OPENERS \
                    and nxt != ")":
                if token in WRITE_REDIRECTS or \
                        (token == ">&" and not is_fd_operand(nxt)):
                    targets.append(nxt)
                index += 1
        elif token in SEPARATORS or token in OPENERS or token == ")":
            if words or targets:
                hit, where = run_segment(words, targets, where, depth)
                words = []
                targets = []
                if hit:
                    return hit
            if token in OPENERS:
                stack.append(where)
            elif token == ")" and stack:
                where = stack.pop()
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
