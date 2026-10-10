#!/usr/bin/env bash
# usage: uat.sh CASE   (CASE: reingest DOSSIER | pdf | url | outside)
set -u
SP=/private/tmp/claude-501/-Users-samuel-Documents-dev-client-dossier/d80e7c1c-97a8-403c-b0e0-19958fd27938/scratchpad/uat
source /Users/samuel/Documents/dev/client-dossier/tests/scenarios/lib-scenario.sh
export SCENARIO_BUDGET_USD=0.3
MASKED="$HOME/.local/bin:/Library/Frameworks/Python.framework/Versions/3.14/bin:/usr/bin:/bin:/usr/sbin:/sbin"
cost() { jsonl_result_field "$1" total_cost_usd; }
case "$1" in
reingest)
  D="$2"
  before="$(ls "$D/sources/transcripts" | tr '\n' ' ')"
  run_claude "$D/incoming" "$SP/reingest.jsonl" "Here is the transcript of the call again: call-transcript.txt. Please ingest it." yes
  after="$(ls "$D/sources/transcripts" | tr '\n' ' ')"
  echo "before: $before"; echo "after:  $after"; echo "cost: $(cost "$SP/reingest.jsonl")"
  ;;
pdf)
  D="$(build_dossier)"; mkdir -p "$D/incoming"
  python3 "$REPO_ROOT/tests/fixtures/make-pdf.py" "$D/incoming/onboarding-pack.pdf" \
    "Acme Consulting supplier onboarding pack, issued 2026-10-06." \
    "Your procurement contact is Priya Raman, procurement lead at Acme Consulting." \
    "Supplier invoices are paid 45 days after receipt." || exit 2
  strip_agents_pointer "$D"; backdate_last_updated "$D" 2026-09-01; commit_baseline "$D" >/dev/null
  echo "dossier: $D"
  PATH="$MASKED"; export PATH
  if command -v pdftotext >/dev/null 2>&1; then echo "MASK FAILED"; exit 2; fi
  echo "pdftotext masked: $(command -v pdftotext || echo absent)"
  run_claude "$D" "$SP/pdf-masked.jsonl" "Acme Consulting sent us their supplier onboarding pack: incoming/onboarding-pack.pdf. Please ingest it." yes
  ls -la "$D/sources/received"; echo "cost: $(cost "$SP/pdf-masked.jsonl")"
  ;;
url)
  D="$(build_dossier)"; strip_agents_pointer "$D"; commit_baseline "$D" >/dev/null
  W="$(mktemp -d)"; python3 "$REPO_ROOT/tests/fixtures/make-pdf.py" "$W/brochure.pdf" "Acme brochure" || exit 2
  PORT="$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1])')"
  (cd "$W" && python3 -u -m http.server "$PORT" --bind 127.0.0.1 >"$SP/server.log" 2>&1 & echo $! >"$SP/server.pid")
  sleep 1
  curl -s -o /dev/null -w "self-check (mine, not the skill): %{http_code}\n" "http://127.0.0.1:$PORT/brochure.pdf"; : >"$SP/server.log.mark"
  # python prints "Serving HTTP on 127.0.0.1 port N"
  echo "dossier: $D port: $PORT"
  run_claude "$D" "$SP/url.jsonl" "Acme posted their brochure at http://127.0.0.1:$PORT/brochure.pdf. Please ingest it." yes
  kill "$(cat "$SP/server.pid")" 2>/dev/null
  echo "server log:"; cat "$SP/server.log"; echo "sources:"; find "$D/sources" -type f | head; echo "cost: $(cost "$SP/url.jsonl")"
  ;;
outside)
  D="$(mktemp -d)"; printf 'Call 2026-10-10\n@00:05 Hello\n' >"$D/note.txt"
  run_claude "$D" "$SP/outside.jsonl" "Please ingest note.txt as a source." yes
  echo "dir: $D"; ls -A "$D"; echo "cost: $(cost "$SP/outside.jsonl")"
  ;;
esac
