#!/usr/bin/env bash
# tests/test-hook-guard-sources.sh — PROTO-05 as amended by D-03 and D-04, and
# the PROTO-08 root rule for hooks: hooks/guard-sources.py is a PreToolUse
# guard that denies every write under the nearest dossier's sources/ (new
# files included, D-03) through the Write family of tools, and heuristically
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

rm -rf "$b"

rm -rf "$d" "$plain" "$e" "$outside"

finish
