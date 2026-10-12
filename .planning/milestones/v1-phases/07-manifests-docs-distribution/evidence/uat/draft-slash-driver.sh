export REPO_ROOT=${REPO_ROOT:-$PWD} SCENARIO_MODEL=haiku SCENARIO_BUDGET_USD=0.3
. $REPO_ROOT/tests/scenarios/lib-scenario.sh
. $REPO_ROOT/tests/dist/lib-dist.sh
scenario_preflight
dir="$(build_dossier)" || exit 2
run_claude "$dir" "$1/draft-slash.jsonl" '/client-dossier:dossier-draft a two-line mail to Jane saying the pilot kickoff moves to next Tuesday' yes
echo "cost $(jsonl_result_field $1/draft-slash.jsonl total_cost_usd) err $(jsonl_result_field $1/draft-slash.jsonl is_error)"
find "$dir/outbound" -type f -newer "$dir/dossier.yaml" | head; for f in $(find "$dir/outbound" -type f -name '*.md'); do echo "== $f"; head -12 "$f"; done
python3 "$REPO_ROOT/scripts/lint.py" "$dir"; echo lint rc=$?
grep -c 'already loaded above' $1/draft-slash.jsonl
