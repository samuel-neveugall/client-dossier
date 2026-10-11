#!/usr/bin/env bash
# tests/test-hook-guard-sources.sh — PROTO-05 as amended by D-03 and D-04, and
# the PROTO-08 root rule for hooks: hooks/guard-sources.py is a PreToolUse
# guard that denies every write under the sources/ of ANY ancestor directory
# holding a dossier.yaml, nested dossiers included (new files included, D-03) through the Write family of tools, and heuristically
# denies the Bash commands that visibly modify an existing file there (D-04).
# The hook is fed stdin JSON the way Claude Code feeds it; no model involved.
#
# Contract asserted on every case: exit 0, empty stderr, and the hook never
# prints an allow decision (a hook `allow` would bypass the user's own
# permission rules). A silent run is "no decision", so Claude Code's normal
# permission flow applies.
set -u

# shellcheck source=./lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SPEC_SENTENCE='sources are immutable; file a correction in the dossier instead'
TRANSCRIPT_REL='sources/transcripts/2026-10-01_kickoff.txt'

# build_dossier — a scaffolded dossier (real init.py) holding one transcript
# with a typo. Echoes its path. Outputs are never written inside it.
build_dossier() {
  local target="$1"
  python3 "$(init_py)" --target "$target" --language en \
    --counterpart 'Acme Consulting|ordering party|Jane Doe' >/dev/null 2>&1
  mkdir -p "$target/sources/transcripts" "$target/sources/received"
  printf '%s\n' '@00:12 Jane Doe: We need the reprot by 2026-10-20.' \
    >"$target/$TRANSCRIPT_REL"
}

# check_common LABEL — every case: exit 0, empty stderr, never `allow`.
check_common() {
  local label="$1"
  assert_eq 0 "$HOOK_STATUS" "$label: exit status 0"
  assert_eq '' "$HOOK_ERR" "$label: empty stderr"
  case "$(hook_field hookSpecificOutput.permissionDecision)" in
    allow)
      echo "FAIL: $label (the hook printed an allow decision)" >&2
      TESTS_FAILED=$((TESTS_FAILED + 1))
      ;;
    *) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  esac
}

# expect_deny LABEL JSON REL — the hook denies, with the spec sentence first
# and REL (the path relative to the dossier root) right after it. REL is a
# glob pattern (unquoted in the `case`), so the case-variant test can accept
# whichever spelling of the first component the filesystem reports.
expect_deny() {
  local label="$1" json="$2" rel="$3" reason
  run_hook guard-sources.py "$json"
  check_common "$label"
  assert_eq deny "$(hook_field hookSpecificOutput.permissionDecision)" "$label: decision is deny"
  assert_eq PreToolUse "$(hook_field hookSpecificOutput.hookEventName)" "$label: hookEventName"
  reason="$(hook_field hookSpecificOutput.permissionDecisionReason)"
  case "$reason" in
    "$SPEC_SENTENCE: "$rel*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
    *)
      echo "FAIL: $label (reason does not start with '$SPEC_SENTENCE: $rel': '$reason')" >&2
      TESTS_FAILED=$((TESTS_FAILED + 1))
      ;;
  esac
}

# expect_silent LABEL JSON — no output at all (no decision).
expect_silent() {
  local label="$1" json="$2"
  run_hook guard-sources.py "$json"
  check_common "$label"
  assert_eq none "$(hook_field hookSpecificOutput.permissionDecision)" "$label: no decision"
  assert_eq '' "$HOOK_OUT" "$label: empty stdout"
}

d=$(scratch_repo)
build_dossier "$d"

# --- Case 1: the Write family under sources/ is denied (D-03) ---
echo '--- Edit, absolute path, existing file ---'
expect_deny 'Edit absolute' \
  "$(hook_json PreToolUse "$d" Edit file_path "$d/$TRANSCRIPT_REL")" "$TRANSCRIPT_REL"

echo '--- Write of a NEW file under sources/ (D-03) ---'
expect_deny 'Write new file' \
  "$(hook_json PreToolUse "$d" Write file_path "$d/sources/received/2026-10-10_new.txt")" \
  'sources/received/2026-10-10_new.txt'

echo '--- MultiEdit and NotebookEdit ---'
expect_deny 'MultiEdit' \
  "$(hook_json PreToolUse "$d" MultiEdit file_path "$d/$TRANSCRIPT_REL")" "$TRANSCRIPT_REL"
expect_deny 'NotebookEdit' \
  "$(hook_json PreToolUse "$d" NotebookEdit notebook_path "$d/sources/received/analysis.ipynb")" \
  'sources/received/analysis.ipynb'

echo '--- Relative paths resolve against the stdin cwd ---'
expect_deny 'Edit relative, cwd = root' \
  "$(hook_json PreToolUse "$d" Edit file_path "$TRANSCRIPT_REL")" "$TRANSCRIPT_REL"
expect_deny 'Edit ../sources, cwd = dossier/' \
  "$(hook_json PreToolUse "$d/dossier" Edit file_path "../$TRANSCRIPT_REL")" "$TRANSCRIPT_REL"

echo '--- Path tricks: .., case variant, symlink ---'
expect_deny 'Edit dossier/../sources' \
  "$(hook_json PreToolUse "$d" Edit file_path "$d/dossier/../$TRANSCRIPT_REL")" "$TRANSCRIPT_REL"
expect_deny 'Write Sources/ case variant' \
  "$(hook_json PreToolUse "$d" Write file_path "$d/Sources/transcripts/x.txt")" '?ources/transcripts/x.txt'
ln -s sources "$d/notes"
expect_deny 'Edit through a symlink to sources' \
  "$(hook_json PreToolUse "$d" Edit file_path "$d/notes/transcripts/2026-10-01_kickoff.txt")" "$TRANSCRIPT_REL"

# --- Case 2: everything else is silent so the normal permission flow applies ---
echo '--- Writes elsewhere in the dossier are not touched ---'
expect_silent 'Edit dossier/HISTORY.md' \
  "$(hook_json PreToolUse "$d" Edit file_path "$d/dossier/HISTORY.md")"
expect_silent 'Write outbound/mails' \
  "$(hook_json PreToolUse "$d" Write file_path "$d/outbound/mails/2026-10-10_x.md")"
expect_silent 'Write knowledge/CONTEXT.md' \
  "$(hook_json PreToolUse "$d" Write file_path "$d/knowledge/CONTEXT.md")"
expect_silent 'Edit a file named like sources but under dossier/' \
  "$(hook_json PreToolUse "$d" Edit file_path "$d/dossier/sources.md")"

echo '--- Outside any dossier ---'
plain=$(mktemp -d)
mkdir -p "$plain/sources"
expect_silent 'Edit under a sources/ folder without dossier.yaml' \
  "$(hook_json PreToolUse "$plain" Edit file_path "$plain/sources/x.txt")"

# --- Case 3: nested dossiers, the nearest one wins (PROTO-08) ---
echo '--- Nested dossier ---'
mkdir -p "$d/clients/acme"
python3 "$(init_py)" --target "$d/clients/acme" --language en \
  --counterpart 'Acme Consulting|ordering party|Jane Doe' >/dev/null 2>&1
expect_deny 'Edit in the inner dossier sources/ (session cwd = outer root)' \
  "$(hook_json PreToolUse "$d" Edit file_path "$d/clients/acme/sources/x.txt")" 'sources/x.txt'
expect_silent 'Edit in the inner dossier dossier/' \
  "$(hook_json PreToolUse "$d" Edit file_path "$d/clients/acme/dossier/HISTORY.md")"

# --- Case 3b: sources/ itself a symlink out of the dossier (R-F1, A-F4) ---
echo '--- sources/ is a symlink to a folder outside the dossier ---'
e=$(scratch_repo)
build_dossier "$e"
outside=$(mktemp -d)
cp -R "$e/sources/." "$outside/"
rm -rf "$e/sources"
ln -s "$outside" "$e/sources"
expect_deny 'Edit existing file through a sources/ symlink' \
  "$(hook_json PreToolUse "$e" Edit file_path "$e/$TRANSCRIPT_REL")" "$TRANSCRIPT_REL"
expect_deny 'Write new file through a sources/ symlink' \
  "$(hook_json PreToolUse "$e" Write file_path "$e/sources/received/new.txt")" 'sources/received/new.txt'
expect_deny 'Edit relative path through a sources/ symlink' \
  "$(hook_json PreToolUse "$e" Edit file_path "$TRANSCRIPT_REL")" "$TRANSCRIPT_REL"
expect_silent 'Edit dossier/HISTORY.md next to a sources/ symlink' \
  "$(hook_json PreToolUse "$e" Edit file_path "$e/dossier/HISTORY.md")"

# --- Case 3c: a dossier.yaml under sources/ is not a new root (A-F1) ---
echo '--- dossier.yaml planted under sources/ ---'
mkdir -p "$d/sources/received/old-export/dossier"
cp "$d/dossier.yaml" "$d/sources/received/old-export/dossier.yaml"
expect_deny 'Edit a file under a root planted inside sources/' \
  "$(hook_json PreToolUse "$d" Edit file_path "$d/sources/received/old-export/dossier/HISTORY.md")" \
  'sources/received/old-export/dossier/HISTORY.md'
expect_deny 'Write into the planted root own sources/' \
  "$(hook_json PreToolUse "$d" Write file_path "$d/sources/received/old-export/sources/x.txt")" \
  'sources/x.txt'
expect_silent 'a legitimate nested dossier outside sources/ is still silent' \
  "$(hook_json PreToolUse "$d" Edit file_path "$d/clients/acme/knowledge/CONTEXT.md")"

# --- Case 4: fail open ---
echo '--- Fail open ---'
expect_silent 'stdin is not JSON' 'not json'
expect_silent 'stdin is an empty object' '{}'
expect_silent 'Edit without file_path' \
  "$(hook_json PreToolUse "$d" Edit old_string x)"
expect_silent 'read-only Bash call' \
  "$(hook_json PreToolUse "$d" Bash command 'ls sources')"
expect_silent 'unknown tool' \
  "$(hook_json PreToolUse "$d" Read file_path "$d/$TRANSCRIPT_REL")"

# --- Case 5: the heuristic Bash guard (D-04) ---
# A fresh dossier, so the fixtures of the cases above (symlink, nested
# dossier) cannot influence the Bash resolution. The guard is a heuristic:
# it catches the visible routes onto an EXISTING source file and lets every
# new file in, which is what ingest and extract-text.sh do.
b=$(scratch_repo)
build_dossier "$b"

# bash_deny LABEL CMD [CWD] [REL] — denied, naming REL, saying where it comes from.
bash_deny() {
  local label="$1" cmd="$2" cwd="${3:-$b}" rel="${4:-$TRANSCRIPT_REL}"
  expect_deny "$label" "$(hook_json PreToolUse "$cwd" Bash command "$cmd")" "$rel"
  case "$(hook_field hookSpecificOutput.permissionDecisionReason)" in
    *'heuristic guard'*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
    *)
      echo "FAIL: $label (reason does not say it comes from the heuristic guard)" >&2
      TESTS_FAILED=$((TESTS_FAILED + 1))
      ;;
  esac
}

# bash_ok LABEL CMD [CWD] — no output at all.
bash_ok() {
  local label="$1" cmd="$2" cwd="${3:-$b}"
  expect_silent "$label" "$(hook_json PreToolUse "$cwd" Bash command "$cmd")"
}

echo '--- Bash: in-place edits are denied ---'
bash_deny 'sed -i with a BSD empty suffix' "sed -i '' 's/reprot/report/' sources/transcripts/2026-10-01_kickoff.txt"
bash_deny 'sed -i.bak' "sed -i.bak s/a/b/ sources/transcripts/2026-10-01_kickoff.txt"
bash_deny 'sed --in-place=.b' "sed --in-place=.b s/a/b/ sources/transcripts/2026-10-01_kickoff.txt"
bash_deny 'sed -Ei' "sed -Ei s/a/b/ sources/transcripts/2026-10-01_kickoff.txt"
bash_deny 'leading NAME=value' "FOO=1 sed -i s/a/b/ sources/transcripts/2026-10-01_kickoff.txt"
bash_deny 'perl -pi' "perl -pi -e 's/a/b/' sources/transcripts/2026-10-01_kickoff.txt"

echo '--- Bash: the directory changes before the edit ---'
bash_deny 'cd sources/transcripts && sed -i' \
  'cd sources/transcripts && sed -i s/a/b/ 2026-10-01_kickoff.txt'
bash_deny 'stdin cwd already under sources/' \
  'sed -i s/a/b/ 2026-10-01_kickoff.txt' "$b/sources/transcripts"
bash_deny 'cd on one line, sed -i on the next' \
  $'cd sources/transcripts\nsed -i s/a/b/ 2026-10-01_kickoff.txt'
bash_deny 'inside a subshell' \
  '(cd sources && rm transcripts/2026-10-01_kickoff.txt)'

echo '--- Bash: delete, move out, overwrite, truncate ---'
bash_deny 'rm a source' "rm sources/transcripts/2026-10-01_kickoff.txt"
bash_deny 'rm -rf sources' 'rm -rf sources' "$b" 'sources'
bash_deny 'mv out of sources/' "mv sources/transcripts/2026-10-01_kickoff.txt /tmp/x.txt"
bash_deny 'redirection >' "echo hi > sources/transcripts/2026-10-01_kickoff.txt"
bash_deny 'redirection >>' "echo hi >> sources/transcripts/2026-10-01_kickoff.txt"
bash_deny 'tee -a' "echo hi | tee -a sources/transcripts/2026-10-01_kickoff.txt"
bash_deny 'truncate' "truncate -s 0 sources/transcripts/2026-10-01_kickoff.txt"
bash_deny 'cp onto an existing source' "cp other.txt sources/transcripts/2026-10-01_kickoff.txt"
bash_deny 'git rm' "git rm sources/transcripts/2026-10-01_kickoff.txt"
bash_deny 'bash -c' "bash -c \"sed -i s/a/b/ sources/transcripts/2026-10-01_kickoff.txt\""

echo '--- Bash: unbalanced quotes, heredocs and comments no longer blind the guard (A-F2, R-F2) ---'
bash_deny 'rm after a comment holding an apostrophe' \
  $'# it\'s a note\nrm sources/transcripts/2026-10-01_kickoff.txt'
bash_deny 'rm after an echo with an apostrophe' \
  "echo it's done; rm sources/transcripts/2026-10-01_kickoff.txt"
bash_deny 'rm on the line after a heredoc whose body has an apostrophe' \
  $'cat <<EOF > /tmp/x\nit\'s a note\nEOF\nrm sources/transcripts/2026-10-01_kickoff.txt'
bash_deny 'a heredoc redirected into an existing source' \
  $'cat > sources/transcripts/2026-10-01_kickoff.txt <<\'EOF\'\nhello\nEOF'
bash_deny 'a quoted <<X does not hide the next line' \
  $'echo "<<X"\nrm sources/transcripts/2026-10-01_kickoff.txt\nX'
bash_ok 'rm sources/x quoted in a heredoc body is text' \
  $'cat <<EOF > /tmp/note.txt\nrm sources/transcripts/2026-10-01_kickoff.txt\nEOF'
bash_ok 'indented heredoc terminator (<<-)' \
  $'cat <<-EOF > /tmp/note.txt\n\tsed -i s/a/b/ sources/transcripts/2026-10-01_kickoff.txt\n\tEOF'

echo '--- Bash: reserved words, functions, cd - and builtin (A-F3) ---'
bash_deny 'if ...; then rm' \
  'if true; then rm sources/transcripts/2026-10-01_kickoff.txt; fi'
bash_deny 'for ...; do rm' \
  'for f in a; do rm sources/transcripts/2026-10-01_kickoff.txt; done'
bash_deny 'while ...; do rm' \
  'while true; do rm sources/transcripts/2026-10-01_kickoff.txt; done'
bash_deny 'brace group' '{ rm sources/transcripts/2026-10-01_kickoff.txt; }'
bash_deny 'negation' '! rm sources/transcripts/2026-10-01_kickoff.txt'
bash_deny 'function definition' 'f(){ rm sources/transcripts/2026-10-01_kickoff.txt; }; f'
bash_deny 'case arm' 'case x in x) rm sources/transcripts/2026-10-01_kickoff.txt;; esac'
bash_deny 'builtin cd then sed -i' \
  'builtin cd sources/transcripts && sed -i s/a/b/ 2026-10-01_kickoff.txt'
bash_ok 'cd - does not crash and the following relative rm is unknown' 'cd - && rm notes.txt'
bash_ok 'reserved words around a harmless command' 'if true; then ls; fi'

echo '--- Bash: >& is a write redirection unless the operand is a fd (R-F3) ---'
bash_deny 'cmd >& existing source' 'echo hi >& sources/transcripts/2026-10-01_kickoff.txt'
bash_ok 'cmd >& new source file' 'echo hi >& sources/received/2026-10-10_new.txt'
bash_ok '2>&1' 'ls 2>&1'
bash_ok '>&2' 'echo err >&2'
bash_ok '>&-' 'echo err >&-'

echo '--- Bash: ln onto an existing source (A-F4) ---'
bash_deny 'hard link to an existing source' 'ln sources/transcripts/2026-10-01_kickoff.txt /tmp/h'
bash_deny 'ln -f over an existing source' 'ln -f other.txt sources/transcripts/2026-10-01_kickoff.txt'
bash_deny 'ln -sf over an existing source' 'ln -sf other.txt sources/transcripts/2026-10-01_kickoff.txt'
bash_ok 'plain symbolic link to a source' 'ln -s sources/transcripts/2026-10-01_kickoff.txt /tmp/l'
bash_ok 'ln between non-source files' 'ln a.txt b.txt'

echo '--- Bash: new files in, reads, and everything the guard cannot judge ---'
bash_ok 'cp a new file into sources/received' 'cp new.pdf sources/received/2026-10-10_brochure.pdf'
bash_ok 'cp into the received directory' 'cp new.pdf sources/received/'
bash_ok 'mv into the received directory' 'mv new.pdf sources/received/'
bash_ok 'redirect to a new file' 'echo x > sources/received/2026-10-10_note.txt'
bash_ok 'cat a source' "cat sources/transcripts/2026-10-01_kickoff.txt"
bash_ok 'grep a source' "grep reprot sources/transcripts/2026-10-01_kickoff.txt"
bash_ok 'mkdir under sources' 'mkdir -p sources/received/2026'
bash_ok 'sed -i on a living file after cd sources' "cd sources && sed -i 's/x/y/' ../dossier/HISTORY.md"
bash_ok 'sed -i on a living file' 'sed -i s/a/b/ dossier/HISTORY.md'
bash_ok 'a subshell cd does not leak' '(cd sources && ls); rm notes.txt'
bash_ok 'a variable operand' 'sed -i s/a/b/ $F'
bash_ok 'an interpreter one-liner' "python3 -c \"open('sources/x','w')\""
bash_ok 'a shlex error' "echo 'unbalanced"
mkdir -p "$plain/sources"
bash_ok 'rm -rf sources outside any dossier' 'rm -rf sources' "$plain"

# --- Case 6: fix round 2 (NF-1 .. NF-6), every reproduced fail-open path ---
S=sources/transcripts/2026-10-01_kickoff.txt

echo '--- Bash: backslash-newline continues the command (NF-1) ---'
bash_deny 'rm with the operand on the next line' $'rm \\\n  '"$S"
bash_deny 'sed -i with the file on the next line' $'sed -i s/a/b/ \\\n  '"$S"
bash_deny 'cp onto a source, operand on the next line' $'cp x \\\n  '"$S"
bash_deny 'cd, continuation, then rm' $'cd \\\n sources/transcripts && rm 2026-10-01_kickoff.txt'
bash_deny 'continuation after a lone apostrophe' "echo it's; rm "$'\\\n  '"$S"
bash_deny 'a trailing backslash on the last line' "rm $S \\"
bash_deny 'a comment ends at its newline, backslash or not' $'true # c \\\nrm '"$S"
bash_ok 'a continuation does not hide a NEW file' $'cp x \\\n  sources/received/2026-10-10_new.txt'
bash_ok 'rm in a single-quoted continuation is text' $'echo \'keep \\\n rm '"$S'"
bash_ok 'rm in a trailing comment is text' "echo hi # rm $S"

echo '--- Bash: a heredoc fed to a shell is code (NF-2) ---'
bash_deny 'bash <<EOF' $'bash <<EOF\nrm '"$S"$'\nEOF'
bash_deny "sh <<'EOF'" $'sh <<\'EOF\'\nrm '"$S"$'\nEOF'
bash_deny 'bash -s <<EOF with sed -i' $'bash -s <<EOF\nsed -i s/a/b/ '"$S"$'\nEOF'
bash_deny 'sudo bash <<EOF' $'sudo bash <<EOF\nrm '"$S"$'\nEOF'
bash_deny "cat <<'EOF' | bash" $'cat <<\'EOF\' | bash\nrm '"$S"$'\nEOF'
bash_deny 'source /dev/stdin <<EOF' $'source /dev/stdin <<EOF\nrm '"$S"$'\nEOF'
bash_deny 'command substitution in an unquoted heredoc' $'cat <<EOF\n$(rm '"$S"$')\nEOF'
bash_deny 'backticks in an unquoted heredoc' $'cat <<EOF\n`rm '"$S"$'`\nEOF'
bash_ok 'command substitution in a quoted heredoc is text' $'cat <<\'EOF\'\n$(rm '"$S"$')\nEOF'
bash_ok 'a harmless bash heredoc' $'bash <<EOF\necho hi\nEOF'
bash_ok 'a heredoc body for python stays text' $'python3 - <<\'PY\'\nrm '"$S"$'\nPY'

echo '--- Bash: a << that is not a heredoc hides nothing (NF-3) ---'
bash_deny 'a shift in $(( ))' $'echo $((1<<X))\nrm '"$S"$'\nX'
bash_deny 'a << inside [[ ]]' $'[[ a<<b ]]\nrm '"$S"$'\nb'
bash_deny 'a << after a comment mark' $'echo hi # <<EOF\nrm '"$S"$'\nEOF'
bash_deny 'a << inside (( ))' $'((x = 1<<EOF))\nrm '"$S"$'\nEOF'
bash_deny 'an apostrophe in double quotes does not cancel a real heredoc' \
  $'echo "it\'s"; cat <<EOF >/dev/null\nbody\nEOF\nrm '"$S"
bash_ok 'a real heredoc after double quotes with an apostrophe' \
  $'echo "it\'s"; cat <<EOF >/dev/null\nrm '"$S"$'\nEOF'

echo '--- Bash: copy onto a source through a sources/ symlink (NF-4) ---'
bash_deny 'cp onto a source via a sources/ symlink' "cp x $S" "$e"
bash_deny 'mv onto a source via a sources/ symlink' "mv x $S" "$e"
bash_deny 'install onto a source via a sources/ symlink' "install x $S" "$e"
bash_deny 'rsync onto a source via a sources/ symlink' "rsync x $S" "$e"
bash_deny 'cp into a directory already holding that name, via the symlink' \
  'cp 2026-10-01_kickoff.txt sources/transcripts/' "$e"
bash_ok 'cp a NEW file via a sources/ symlink' 'cp x sources/received/2026-10-10_new.txt' "$e"
bash_ok 'cp into a directory via the symlink, name not taken' 'cp new.pdf sources/received/' "$e"
bash_ok 'a file_source.py style call, new file via the symlink' \
  'python3 /p/file_source.py in.pdf sources/received/2026-10-10_in.pdf' "$e"
bash_ok 'curl -o a new file via the symlink' 'curl -o sources/received/2026-10-10_dl.pdf https://example.org' "$e"

echo '--- Bash: an unknown working directory still judges the operand (NF-5) ---'
bash_deny 'cd - then a root-relative rm' "cd - ; rm $S"
bash_deny 'cd $X then a root-relative rm' "cd \$X; rm $S"
bash_deny 'cd "$(pwd)" then a root-relative rm' "cd \"\$(pwd)\"; rm $S"
bash_deny 'cd - back to the directory the previous cd left (OLDPWD)' \
  'cd sources/transcripts; cd /; cd -; rm 2026-10-01_kickoff.txt'
bash_ok 'cd - back to the root, the relative file is not a source there' \
  'cd sources/transcripts; cd -; rm 2026-10-01_kickoff.txt'
bash_deny 'cd $X after a known cd, relative to the last known one' \
  'cd sources/transcripts; cd $X; rm 2026-10-01_kickoff.txt'
bash_deny 'popd, then the last known directory' \
  'cd sources/transcripts; popd; rm 2026-10-01_kickoff.txt'
bash_deny 'function keyword, no parentheses' "function f { rm $S; }"
bash_deny 'function keyword with parentheses' "function f() { rm $S; }"
bash_ok 'an unknown directory and a file that does not exist' 'cd "$(pwd)"; rm notes.txt'
bash_ok 'an unknown directory, a NEW file copied in' 'cd $X; cp x sources/received/2026-10-10_new.txt'

# --- Case 7: the last bounded round (F1 .. F7, D-17) ---
ROOT_NAME="$(basename "$b")"

echo '--- Bash: a backslash escapes the next character, ANSI-C quotes (F1) ---'
bash_deny 'an escaped space does not open a comment' "echo a\\ #b; rm $S"
bash_deny 'an escaped space, comment mark on the next word' "echo a\\ #b rm; rm $S"
bash_deny 'ANSI-C quotes holding an escaped apostrophe' "echo \$'it\\'s'; rm $S"
bash_deny 'ANSI-C quotes holding an escaped apostrophe and a hash' "echo \$'a\\' #'; rm $S"
bash_ok 'rm inside an ANSI-C string is text' "echo \$'it\\'s: rm $S'"
bash_ok 'a real comment after a word is still a comment' "echo a #c; rm $S"
bash_ok 'an escaped hash is not a comment, nothing to delete' "echo a\\ #b; rm notes.txt"

echo '--- Bash: a string spanning lines carries its state (F2) ---'
bash_deny 'a <<EOF inside a double-quoted multi-line string' \
  $'echo "\ncat <<EOF\n"\nrm '"$S"$'\nEOF'
bash_deny 'a <<EOF inside a single-quoted multi-line string' \
  $'echo \'\ncat <<EOF\n\'\nrm '"$S"$'\nEOF'
bash_deny 'a <<EOF inside an ANSI-C multi-line string' \
  $'echo $\'\\\'\ncat <<EOF\n\'\nrm '"$S"$'\nEOF'
bash_ok 'a real heredoc after a multi-line string' \
  $'echo "a\nb"\ncat <<EOF >/dev/null\nrm '"$S"$'\nEOF'
bash_ok 'a stray apostrophe still leaves a later heredoc a heredoc' \
  $'echo it\'s\ncat <<EOF >/dev/null\nrm '"$S"$'\nEOF'

echo '--- Bash: cd -, pushd and popd are followed (F4) ---'
bash_deny 'cd / ; cd - ; rm (OLDPWD is the dossier)' "cd /; cd -; rm $S"
bash_deny 'cd sources, cd /, cd -, then the relative name' \
  'cd sources/transcripts; cd /; cd -; rm 2026-10-01_kickoff.txt'
bash_deny 'pushd into sources then a relative rm' \
  'pushd sources/transcripts >/dev/null; rm 2026-10-01_kickoff.txt'
bash_deny 'pushd, pushd, popd lands in sources again' \
  'pushd sources/transcripts >/dev/null; pushd /tmp >/dev/null; popd >/dev/null; rm 2026-10-01_kickoff.txt'
bash_ok 'pushd sources && popd, then a living file' 'pushd sources && popd; rm dossier/HISTORY.md'
bash_ok 'pushd sources && popd, then a relative name that is not a source' \
  'pushd sources/transcripts >/dev/null; popd >/dev/null; rm 2026-10-01_kickoff.txt'
bash_ok 'cd sources; cd -; a living file' 'cd sources; cd -; rm dossier/HISTORY.md'
bash_deny 'cd $X from dossier/ is judged against the root above' \
  "cd \$X; rm $S" "$b/dossier"
bash_deny 'cd "$(pwd)" from dossier/ is judged against the root above' \
  "cd \"\$(pwd)\"; rm $S" "$b/dossier"
bash_deny 'popd on an empty stack from dossier/ is judged against the root above' \
  "popd; rm $S" "$b/dossier"
bash_ok 'cd $X from dossier/, a living file' 'cd $X; rm HISTORY.md' "$b/dossier"
bash_ok 'cd into a directory that is not there is not followed' 'cd nowhere && ls'
bash_deny 'cd into a missing directory keeps the dossier root in view' "cd nowhere; rm $S"
bash_deny 'a stray ANSI-C opener blinds nothing' "echo \$'oops; rm $S"
ln -s "../$TRANSCRIPT_REL" "$b/dossier/link-to-source.txt"
bash_deny 'sed -i through a symlink that leads to a source' \
  'sed -i s/a/b/ dossier/link-to-source.txt'
bash_ok 'sed -n through that symlink only reads' 'sed -n p dossier/link-to-source.txt'

echo '--- Bash: bounds, a huge operand or a huge list is not resolved (F3) ---'
LONG="$(python3 -c 'print("/".join(["a"] * 3000))')"
bash_deny 'an operand beyond the bound that shows a sources component' "rm $LONG/sources/x" "$b" 'sources'

bash_ok 'an operand beyond the bound that shows none' "rm $LONG/x"
MANY="$(python3 -c 'print(" ".join("x%d" % i for i in range(1500)))')"
bash_deny 'operands beyond the bound, a sources path among them' "rm $MANY $S" "$b" 'sources'

bash_ok 'operands beyond the bound, none shows sources' "rm $MANY"
SEGMENTS="$(python3 -c 'print("rm x; " * 5000, end="")')"
bash_deny 'past the judged-paths budget, a visible sources path is still refused' "${SEGMENTS}rm $S" "$b" 'sources'
bash_ok 'past the judged-paths budget, only what the text shows is read (accepted bound)' \
  "${SEGMENTS}cd sources/transcripts; rm 2026-10-01_kickoff.txt"
bash_ok 'a new file copied in after a long list of sources' "cp $MANY sources/received/2026-10-10_new.txt"

echo '--- Bash: globs and braces on the sources component (F5) ---'
bash_deny 'rm sour*/...' 'rm sour*/transcripts/2026-10-01_kickoff.txt'
bash_deny 'rm s?urces/...' 'rm s?urces/transcripts/2026-10-01_kickoff.txt'
bash_deny 'rm [s]ources/...' 'rm [s]ources/transcripts/2026-10-01_kickoff.txt'
bash_deny 'rm ./so*/...' 'rm ./so*/transcripts/2026-10-01_kickoff.txt'
bash_deny 'rm */transcripts/...' 'rm */transcripts/2026-10-01_kickoff.txt'
bash_deny 'rm {sources/...,x}' 'rm {sources/transcripts/2026-10-01_kickoff.txt,x}'
bash_deny 'rm sources/{a,b}' 'rm sources/{transcripts/2026-10-01_kickoff.txt,nothing}'
bash_deny 'rm sources/*' 'rm sources/transcripts/*.txt' "$b" 'sources/transcripts/'
bash_deny 'mv s*/... out' 'mv s*/transcripts/2026-10-01_kickoff.txt /tmp/x'
bash_deny 'sed -i on a glob' 'sed -i s/a/b/ sour*/transcripts/2026-10-01_kickoff.txt'
bash_ok 'a glob that cannot match sources' 'rm dossier/*.md'
bash_ok 'a glob on another name' 'rm s*.txt'
nos=$(mktemp -d)
cp "$b/dossier.yaml" "$nos/dossier.yaml"
bash_ok 'a glob in a dossier that has no sources folder' 'rm sour*/x' "$nos"
bash_ok 'a lone * in a dossier that has no sources folder' 'rm -rf *' "$nos"
bash_ok 'a brace expansion on living files' 'rm dossier/{HISTORY,OPEN-QUESTIONS}.md'
bash_ok 'reading through a glob' 'cat sour*/transcripts/*.txt'

echo '--- Bash: removing or moving a parent that holds sources/ (F5) ---'
bash_deny 'rm -rf . at the dossier root' 'rm -rf .' "$b" 'sources'
bash_deny 'rm -rf * at the dossier root' 'rm -rf *' "$b" 'sources'
bash_deny 'rm -rf ./* at the dossier root' 'rm -rf ./*' "$b" 'sources'
bash_deny 'rm -rf .. from dossier/' 'rm -rf ..' "$b/dossier" 'sources'
bash_deny 'rm -rf ../../NAME from dossier/' "rm -rf ../../$ROOT_NAME" "$b/dossier" 'sources'
bash_deny 'rm -rf of the dossier by absolute path' "rm -rf $b" "$plain" 'sources'
bash_deny 'rm -rf of a parent listing the dossier by glob' "rm -rf ${b%/*}/${ROOT_NAME%?}*" "$plain" 'sources'
bash_deny 'mv . ../x at the dossier root' 'mv . ../x' "$b" 'sources'
bash_deny 'mv the dossier by relative path' "mv ../../$ROOT_NAME /tmp/moved" "$b/dossier" 'sources'
bash_deny 'git rm -r .' 'git rm -r .' "$b" 'sources'
bash_ok 'rm -rf . inside dossier/' 'rm -rf .' "$b/dossier"
bash_ok 'rm -rf * inside dossier/' 'rm -rf *' "$b/dossier"
bash_ok 'rm -rf a plain folder' 'rm -rf build'
bash_ok 'rm -rf . outside any dossier' 'rm -rf .' "$plain"
bash_ok 'rm -rf * outside any dossier' 'rm -rf *' "$plain"
bash_ok 'cp -r the dossier root' 'cp -r . /tmp/copy'
bash_ok 'mv a living file' 'mv dossier/HISTORY.md dossier/OLD.md'

echo '--- Bash: more editing verbs (F5) ---'
bash_deny 'gsed -i' "gsed -i s/a/b/ $S"
bash_deny 'patch FILE' "patch $S fix.diff"
bash_deny 'patch -p0 FILE < diff' "patch -p0 $S < fix.diff"
bash_deny 'patch -o FILE' "patch -o $S in.txt fix.diff"
bash_deny 'awk -i inplace' "awk -i inplace '{print}' $S"
bash_deny 'gawk -i inplace' "gawk -i inplace '{print}' $S"
bash_deny 'gawk -iinplace' "gawk -iinplace '{print}' $S"
bash_deny 'ed FILE' "ed $S"
bash_deny 'ed -s FILE' "ed -s $S"
bash_deny 'ex FILE' "ex $S"
bash_deny 'ex -s FILE' "ex -s $S"
bash_deny 'vim -es FILE' "vim -es $S"
bash_deny 'vi -es FILE' "vi -es $S"
bash_deny 'vim -E -s FILE' "vim -E -s $S"
bash_deny 'sponge FILE' "echo x | sponge $S"
bash_ok 'gsed -n on a source' "gsed -n p $S"
bash_ok 'patch a living file' 'patch dossier/HISTORY.md fix.diff'
bash_ok 'patch --dry-run on a source' "patch --dry-run $S fix.diff"
bash_ok 'awk without inplace' "awk '{print}' $S"
bash_ok 'gawk -i inplace on a living file' "gawk -i inplace '{print}' dossier/HISTORY.md"
bash_ok 'ed a living file' 'ed dossier/HISTORY.md'
bash_ok 'vim -es a living file' 'vim -es dossier/HISTORY.md'
bash_ok 'vim a source to read it' "vim $S"
bash_ok 'sponge a living file' 'sort dossier/HISTORY.md | sponge dossier/HISTORY.md'
bash_ok 'sponge a new file in sources/received' 'echo x | sponge sources/received/2026-10-10_new.txt'

echo '--- Bash: wrappers with options and numeric arguments (F5) ---'
bash_deny 'timeout 5 rm' "timeout 5 rm $S"
bash_deny 'timeout 1.5m rm' "timeout 1.5m rm $S"
bash_deny 'timeout -s KILL 5 rm' "timeout -s KILL 5 rm $S"
bash_deny 'timeout --signal=KILL 5 rm' "timeout --signal=KILL 5 rm $S"
bash_deny 'nice rm' "nice rm $S"
bash_deny 'nice -n 5 rm' "nice -n 5 rm $S"
bash_deny 'nice -5 rm' "nice -5 rm $S"
bash_deny 'ionice -c 3 rm' "ionice -c 3 rm $S"
bash_deny 'ionice -c3 -n7 rm' "ionice -c3 -n7 rm $S"
bash_deny 'stdbuf -oL rm' "stdbuf -oL rm $S"
bash_deny 'stdbuf -o L rm' "stdbuf -o L rm $S"
bash_deny 'caffeinate rm' "caffeinate rm $S"
bash_deny 'caffeinate -i rm' "caffeinate -i rm $S"
bash_deny 'caffeinate -t 60 rm' "caffeinate -t 60 rm $S"
bash_deny 'sudo nice -n 5 timeout 10 rm' "sudo nice -n 5 timeout 10 rm $S"
bash_deny 'timeout 5 sed -i' "timeout 5 sed -i s/a/b/ $S"
bash_ok 'timeout 5 on a living file' 'timeout 5 rm dossier/HISTORY.md'
bash_ok 'nice -n 5 reading a source' "nice -n 5 cat $S"
bash_ok 'timeout 5 cp a new file' 'timeout 5 cp new.pdf sources/received/2026-10-10_new.pdf'

echo '--- Bash: what the phase depends on stays allowed ---'
bash_ok 'file_source.py to a new received file' \
  'python3 "${CLAUDE_SKILL_DIR}/scripts/file_source.py" in.pdf sources/received/2026-10-10_in.pdf'
bash_ok 'file_source.py behind a wrapper' \
  'timeout 30 python3 /p/scripts/file_source.py in.pdf sources/received/2026-10-10_in.pdf'
bash_ok 'pdftotext into a new source file' 'pdftotext in.pdf sources/received/2026-10-10_in.txt'
bash_ok 'pdftotext reading a source' "pdftotext sources/received/x.pdf dossier/x.txt"

echo '--- Bash: linear cost on pathological commands, never a timeout (NF-6) ---'
PERF_OUT="$(python3 - "$(hooks_dir)/guard-sources.py" "$b" <<'PY'
import json, subprocess, sys, time
guard, cwd = sys.argv[1], sys.argv[2]
MB = 1024 * 1024
S = "sources/transcripts/2026-10-01_kickoff.txt"
shapes = [
    ("one 1 MB word", "echo " + "a" * MB, False),
    ("unbalanced quote then separators", "echo 'x; " + "a;" * (MB // 2), False),
    ("unbalanced quote, one segment", "echo 'x " + "a" * MB, False),
    ("many heredoc operators, no terminator", "cat <<E\n" * (MB // 8), False),
    ("many heredoc operators on one line", "cat <<E " * (MB // 8), False),
    ("<<a repeated on one line", "<<a" * (MB // 3), False),
    ("heredoc operators and a million terminators", "<<a" * 64 + "\n" + "a\n" * (MB // 2), False),
    ("an apostrophe on every line", "echo it's fine\n" * (MB // 15), False),
    ("a million open parentheses", "(" * (MB // 2), False),
    ("a huge command that still ends in a deny", "echo a;" * (MB // 14) + "rm " + S, True),
    ("a deny first, then a huge tail", "rm " + S + "; " + "echo a;" * (MB // 7), True),
    ("a million distinct operands", "rm " + " ".join("x%d" % i for i in range(MB // 7)), False),
    ("distinct operands after an unknown cd", "cd $X; rm " + " ".join("a/b/f%d" % i for i in range(MB // 10)), False),
    ("distinct redirections", " ".join(">x%d" % i for i in range(MB // 8)), False),
    ("distinct tee operands", "tee " + " ".join("x%d" % i for i in range(MB // 7)), False),
    ("distinct mv operands", "mv " + " ".join("x%d" % i for i in range(MB // 7)) + " dest", False),
    ("sed -i over distinct operands", "sed -i s/a/b/ " + " ".join("x%d" % i for i in range(MB // 7)), False),
    ("distinct segments after an unknown cd", "".join("cd $X; rm f%d; " % i for i in range(MB // 18)), False),
    ("distinct redirection segments", "".join("echo >f%d;" % i for i in range(MB // 10)), False),
    ("a chain of cd into absent directories", "".join("cd d%d && " % i for i in range(MB // 10)), False),
    ("a chain of pushd", "pushd sources && " * (MB // 17), False),
    ("a chain of cd .", "cd . && " * (MB // 8), False),
    ("a 500 000 component path", "rm " + "/".join(["a"] * (MB // 2)), False),
    ("a 32 000 component path, then a visible sources", "rm " + "/".join(["a"] * 32000) + "; rm " + S, True),
    ("a huge operand holding a sources component", "rm " + "/".join(["a"] * 20000) + "/sources/x", True),
    ("more operands than are judged, sources among them", "rm " + " ".join("x%d" % i for i in range(5000)) + " " + S, True),
    ("a million glob and brace characters", "rm " + "{a,b}" * 4000 + " " + "*/" * 100000, False),
    ("a million ANSI-C openers", "echo " + "$'" * (MB // 2), False),
    ("escaped ANSI-C openers", "echo " + "$'\\'" * (MB // 4), False),
    ("rm -rf * repeated", "rm -rf *; " * (MB // 10), True),
]
# Codex apply_patch (D-05, plan 07-03): the same 1 MB bounds hold for patch text.
patch_shapes = [
    ("apply_patch: 1 MB of Add File headers outside sources",
     "".join("*** Add File: dossier/n%d.md\n+x\n" % i for i in range(MB // 30)), False),
    ("apply_patch: 1 MB of headers, the last one under sources",
     "".join("*** Add File: dossier/n%d.md\n+x\n" % i for i in range(MB // 30))
     + "*** Update File: " + S + "\n", True),
    ("apply_patch: 1 MB of Update headers, the last one under sources",
     "".join("*** Update File: outbound/m%d.md\n" % i for i in range(MB // 28))
     + "*** Delete File: " + S + "\n", True),
    ("apply_patch: one 1 MB header line", "*** Add File: " + "a" * MB + "\n", False),
    ("apply_patch: 1 MB of added lines", "*** Add File: dossier/x.md\n" + "+y\n" * (MB // 3), False),
]
bad = 0
cases = [("Bash",) + shape for shape in shapes] + [("apply_patch",) + shape for shape in patch_shapes]
for tool, name, command, want_deny in cases:
    stdin = json.dumps({"tool_name": tool, "tool_input": {"command": command}, "cwd": cwd})
    start = time.time()
    try:
        proc = subprocess.run([sys.executable, guard], input=stdin, capture_output=True,
                              text=True, timeout=10)
        status, out = proc.returncode, proc.stdout
    except subprocess.TimeoutExpired:
        status, out = "timeout", ""
    took = time.time() - start
    denied = '"deny"' in out
    ok = status == 0 and took < 4 and denied == want_deny
    bad += 0 if ok else 1
    print("%s %s: %.2fs status=%s denied=%s" % ("ok  " if ok else "FAIL", name, took, status, denied))
sys.exit(1 if bad else 0)
PY
)"
PERF_STATUS=$?
printf '%s\n' "$PERF_OUT"
assert_eq 0 "$PERF_STATUS" 'every 1 MB command is judged in under 4 s, exit 0'

# --- Codex apply_patch (D-05, plan 07-03) ---
# Codex edits files through a PreToolUse call named apply_patch whose
# tool_input.command is the patch text (07-RESEARCH Pattern 8). A hunk header
# is a line starting at column 0 with `*** Add File: `, `*** Update File: `,
# `*** Delete File: ` or `*** Move to: `; added lines start with `+`.
# mkpatch LINE... — a patch envelope around the given lines.
mkpatch() { printf '*** Begin Patch\n'; printf '%s\n' "$@"; printf '*** End Patch\n'; }
patch_json() { hook_json PreToolUse "$1" apply_patch command "$2"; }

echo '--- apply_patch: headers under sources/ are denied ---'
expect_deny 'apply_patch Update File of a source' \
  "$(patch_json "$d" "$(mkpatch "*** Update File: $TRANSCRIPT_REL" '@@' '-reprot' '+report')")" "$TRANSCRIPT_REL"
expect_deny 'apply_patch Add File of a NEW source (as for Write, D-03)' \
  "$(patch_json "$d" "$(mkpatch '*** Add File: sources/received/new.txt' '+hello')")" 'sources/received/new.txt'
expect_deny 'apply_patch Delete File of a source' \
  "$(patch_json "$d" "$(mkpatch "*** Delete File: $TRANSCRIPT_REL")")" "$TRANSCRIPT_REL"
expect_deny 'apply_patch Move to a path under sources/' \
  "$(patch_json "$d" "$(mkpatch '*** Update File: dossier/HISTORY.md' '*** Move to: sources/received/moved.md' '@@' '-a' '+b')")" \
  'sources/received/moved.md'
expect_deny 'apply_patch Move of a source out of sources/' \
  "$(patch_json "$d" "$(mkpatch "*** Update File: $TRANSCRIPT_REL" '*** Move to: dossier/moved.txt' '@@' '-a' '+b')")" "$TRANSCRIPT_REL"
expect_deny 'apply_patch absolute header path' \
  "$(patch_json "$d" "$(mkpatch "*** Update File: $d/$TRANSCRIPT_REL" '@@' '-a' '+b')")" "$TRANSCRIPT_REL"
expect_deny 'apply_patch dot-dot traversal into sources/' \
  "$(patch_json "$d" "$(mkpatch "*** Update File: dossier/../$TRANSCRIPT_REL" '@@' '-a' '+b')")" "$TRANSCRIPT_REL"
expect_deny 'apply_patch two files, the second under sources/' \
  "$(patch_json "$d" "$(mkpatch '*** Update File: dossier/HISTORY.md' '@@' '-a' '+b' '*** Add File: sources/received/second.txt' '+x')")" \
  'sources/received/second.txt'
expect_deny 'apply_patch CRLF line endings' \
  "$(patch_json "$d" "$(printf '*** Begin Patch\r\n*** Update File: %s\r\n@@\r\n-a\r\n+b\r\n*** End Patch\r\n' "$TRANSCRIPT_REL")")" "$TRANSCRIPT_REL"
expect_deny 'apply_patch relative header from a subfolder cwd' \
  "$(patch_json "$d/dossier" "$(mkpatch "*** Update File: ../$TRANSCRIPT_REL" '@@' '-a' '+b')")" "$TRANSCRIPT_REL"
expect_deny 'apply_patch header with surrounding spaces' \
  "$(patch_json "$d" "$(mkpatch "*** Update File:   $TRANSCRIPT_REL  " '@@' '-a' '+b')")" "$TRANSCRIPT_REL"

# Codex trims a line before it reads a header, so an indented header counts (the
# safe side); a `+` line never does, and a header under another folder stays silent.
expect_deny 'apply_patch indented header after an added file (Codex trims)' \
  "$(patch_json "$d" "$(mkpatch '*** Add File: dossier/notes.md' '+x' "  *** Update File: $TRANSCRIPT_REL")")" "$TRANSCRIPT_REL"

echo '--- apply_patch: everything else is silent ---'
expect_silent 'apply_patch on living files only' \
  "$(patch_json "$d" "$(mkpatch '*** Update File: dossier/HISTORY.md' '@@' '-a' '+b' '*** Add File: outbound/mails/2026-10-11_note.md' '+Hello')")"
expect_silent 'apply_patch whose added line looks like a sources header' \
  "$(patch_json "$d" "$(mkpatch '*** Add File: dossier/notes.md' '+*** Update File: sources/x.txt' '+*** Move to: sources/y.txt')")"
expect_silent 'apply_patch with no header' \
  "$(patch_json "$d" 'just some text about sources/transcripts')"
expect_silent 'apply_patch with an empty header path' \
  "$(patch_json "$d" "$(mkpatch '*** Update File: ')")"
expect_silent 'apply_patch with an empty command' "$(patch_json "$d" '')"
expect_silent 'apply_patch with a numeric command' \
  "$(python3 -c 'import json, sys
print(json.dumps({"tool_name": "apply_patch", "tool_input": {"command": 12}, "cwd": sys.argv[1]}))' "$d")"
expect_silent 'apply_patch with a list command' \
  "$(python3 -c 'import json, sys
print(json.dumps({"tool_name": "apply_patch", "tool_input": {"command": ["apply_patch", "*** Update File: sources/x"]}, "cwd": sys.argv[1]}))' "$d")"
expect_silent 'apply_patch on sources/ outside any dossier' \
  "$(patch_json "$outside" "$(mkpatch "*** Update File: $TRANSCRIPT_REL" '@@' '-a' '+b')")"
expect_silent 'apply_patch sources header with a sibling name' \
  "$(patch_json "$d" "$(mkpatch '*** Update File: sources-old/x.txt' '*** Add File: mysources/y.txt')")"

echo '--- apply_patch: past the judged budget a visible sources still denies ---'
bigpatch="$(python3 -c 'import sys
n = 5000
sys.stdout.write("*** Begin Patch\n" + "".join("*** Add File: dossier/n%d.md\n+x\n" % i for i in range(n))
                 + "*** Add File: dossier/deep/sources/z.txt\n+x\n*** End Patch\n")')"
run_hook guard-sources.py "$(patch_json "$d" "$bigpatch")"
check_common 'apply_patch past MAX_JUDGED with a visible sources component'
assert_eq deny "$(hook_field hookSpecificOutput.permissionDecision)" 'apply_patch past MAX_JUDGED: visible sources denies'

echo '--- apply_patch: end to end through the hooks.json command, Codex-shaped stdin ---'
HOOK_CMD="$(python3 -c 'import json, sys
d = json.load(open(sys.argv[1]))
print(d["hooks"]["PreToolUse"][0]["hooks"][0]["command"])' "$REPO_ROOT/hooks/hooks.json")"
E2E_ERR="$(mktemp)"
E2E_STATUS=0
E2E_OUT="$(patch_json "$d" "$(mkpatch "*** Update File: $TRANSCRIPT_REL" '@@' '-reprot' '+report')" \
  | CLAUDE_PLUGIN_ROOT="$REPO_ROOT" sh -c "$HOOK_CMD" 2>"$E2E_ERR")" || E2E_STATUS=$?
assert_eq 0 "$E2E_STATUS" 'apply_patch end to end: exit status 0'
assert_eq '' "$(cat "$E2E_ERR")" 'apply_patch end to end: empty stderr'
rm -f "$E2E_ERR"
assert_eq deny "$(printf '%s' "$E2E_OUT" | python3 -c 'import json, sys
print(json.load(sys.stdin)["hookSpecificOutput"]["permissionDecision"])')" 'apply_patch end to end: decision is deny'
case "$E2E_OUT" in
  *"$SPEC_SENTENCE: $TRANSCRIPT_REL"*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  *) echo "FAIL: apply_patch end to end: reason lacks the spec sentence and path: $E2E_OUT" >&2
     TESTS_FAILED=$((TESTS_FAILED + 1)) ;;
esac


rm -rf "$b"

rm -rf "$d" "$plain" "$e" "$outside" "$nos"

finish
