#!/usr/bin/env bash
# tests/test-init-quoting.sh — R8-F1: the dossier-init skill states the POSIX single-quote
# escaping rule, and the rule round-trips through a real bash: a value holding an
# apostrophe (L'Oréal, O'Brien, accord de l'intéressé) reaches the script as ONE intact
# argument, and an end-to-end init.py run writes the exact name into confidential_names.
# No model, no network. bash 3.2, no arrays.
set -u

# shellcheck source=./lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SKILL="$REPO_ROOT/skills/dossier-init/SKILL.md"

echo '--- the skill states the escaping rule ---'
has_fixed() {
  if tr '\n' ' ' <"$SKILL" | tr -s ' ' | grep -qF -- "$1"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "FAIL: skill lacks: $1" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}
has_fixed "write each single quote inside it as \`'\\''\`"
has_fixed "'L'\\''Oréal|CEO|a@b.fr'"
has_fixed "'accord de l'\\''intéressé'"
has_fixed 'A value holding a line break is refused'
has_fixed '`--consent-source`'

# R9-1: the rule precedes the first call that takes a quoted value (step 4's --propose-renames),
# and step 6 only reminds of it in one line.
echo '--- the rule is stated before the first call (R9-1) ---'
rule_line=$(grep -nF "Quoting rule, for every value" "$SKILL" | head -1 | cut -d: -f1)
first_call=$(grep -nF -e "--target '" "$SKILL" | head -1 | cut -d: -f1)
step4=$(grep -n '^## Step 4' "$SKILL" | head -1 | cut -d: -f1)
step6=$(grep -n '^## Step 6' "$SKILL" | head -1 | cut -d: -f1)
if [ -n "$rule_line" ] && [ -n "$first_call" ] && [ -n "$step4" ] && [ -n "$step6" ] \
   && [ "$rule_line" -gt "$step4" ] && [ "$rule_line" -lt "$first_call" ] && [ "$rule_line" -lt "$step6" ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "FAIL: quoting rule (line ${rule_line:-none}) is not between step 4 and the first --target call (line ${first_call:-none})" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
if [ "$(grep -cF "Quoting rule, for every value" "$SKILL")" = 1 ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "FAIL: the full quoting rule must appear exactly once" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
has_fixed "Quote every value as in the quoting rule of step 4"
if sed -n "${step6},\$p" "$SKILL" | grep -qF "Quote every value as in the quoting rule of step 4"; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "FAIL: step 6 lacks the one-line reminder" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# esc VALUE — the rule as the skill states it: ' becomes '\'' inside single quotes.
esc() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

echoargs() {
  local n=0 a
  for a in "$@"; do n=$((n + 1)); printf '%s\n' "$a"; done
  printf 'count=%s\n' "$n"
}

echo '--- bash round trip: one argument, intact ---'
for v in "L'Oréal" "O'Brien" "accord de l'intéressé" "L'Oréal|CEO|a@b.fr" "it's a;b|c"; do
  out="$(eval "echoargs --x $(esc "$v")")"
  assert_eq "--x
$v
count=2" "$out" "echoargs receives one intact argument for: $v"
done
# The documented example literal, pasted from the skill, evaluates to one argument.
out="$(eval "echoargs --counterpart 'L'\\''Oréal|CEO|a@b.fr'")"
assert_eq "--counterpart
L'Oréal|CEO|a@b.fr
count=2" "$out" 'the skill example literal is one argument'

echo '--- end to end: init.py keeps the exact name ---'
d=$(scratch_repo)
st=0
cmd="python3 $(esc "$(init_py)") --target $(esc "$d") --language en"
cmd="$cmd --counterpart $(esc "L'Oréal|CEO|a@b.fr")"
cmd="$cmd --counterpart $(esc "O'Brien Ltd|supplier|bob@o.example")"
cmd="$cmd --confidential-name $(esc "L'Oréal")"
cmd="$cmd --confidential-name $(esc "O'Brien")"
cmd="$cmd --consent-recorded true --consent-source $(esc "accord de l'intéressé")"
eval "$cmd" >"$d.out" 2>"$d.err" || st=$?
assert_eq 0 "$st" 'init.py exits 0 with apostrophe values'
assert_file "$d/dossier.yaml"
assert_grep "L'Oréal" "$d/dossier.yaml"
assert_not_grep 'LOréal' "$d/dossier.yaml"
assert_grep "O'Brien" "$d/dossier.yaml"
assert_grep "accord de l'intéressé" "$d/dossier.yaml"
# Read the stored value with the linter's own reader, not with a grep.
names="$(python3 - "$REPO_ROOT/scripts" "$d/dossier.yaml" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import lint
findings = []
data = lint.load_config(sys.argv[2], findings)
print("[" + ", ".join("'%s'" % n for n in sorted(data["confidential_names"])) + "]")
PY
)"
assert_eq "['L'Oréal', 'O'Brien']" "$names" 'confidential_names holds L'"'"'Oréal and O'"'"'Brien exactly'
rm -rf "$d" "$d.out" "$d.err" "$d.names"
finish
