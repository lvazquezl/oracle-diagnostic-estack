#!/usr/bin/env bash
# PHASE 11 — RCA EXECUTION & EVIDENCE VALIDATION HARDENING, sección 6: control de mutation
# testing. Demuestra que la suite es realmente sensible a un defecto de causalidad — no sólo que
# "algo se ejecutó" — alterando intencionalmente una regla en una copia temporal (nunca el catálogo
# real versionado) y verificando que el caso positivo YA NO confirma. La mutación se escribe
# únicamente en $TMPDIR (borrado por el trap) y jamás toca rca_engine/rules/default_rules.json.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/rca_engine_e2e_helpers.sh"
FAIL=0

TMPDIR="$ROOT/tests/.tmp_rca_mutation_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT
cp "$ROOT/tests/fixtures/rca_engine/positive_confirmed.json" "$TMPDIR/fixture.json"

# Baseline: unmodified rules -> CONFIRMED (already covered by test_rca_e2e_confirmed_with_causal_evidence,
# re-verified here as the mutation control's own baseline so this test is self-contained).
rca_engine_run "$TMPDIR" "fixture.json" "" "" "baseline.json"
[ "$RCA_ENGINE_RUN_RC" -eq 0 ] || { echo "[FAIL] baseline run exit $RCA_ENGINE_RUN_RC"; exit 1; }
BASELINE_OK=$(rca_engine_read_json "$TMPDIR" "
import json
r = json.load(open('baseline.json'))
print('CONFIRMED' if r['root_cause']['completeness'] == 'CONFIRMED' else 'NOT_CONFIRMED')
")
if [ "$BASELINE_OK" != "CONFIRMED" ]; then
  echo "[FAIL] baseline (unmutated rules) did not CONFIRM — mutation control cannot proceed"
  exit 1
fi

# Mutation: copy the real rules catalog into TMPDIR (relative paths only — never a POSIX absolute
# path crossing the bash/python boundary, see tests/lib/rca_engine_e2e_helpers.sh) and flip
# RULE-OS-PROCESS-LIMIT-001's min_independent_sources to an unreachable value AND its
# supporting-condition threshold to an impossible one — a genuine causality-logic defect if the
# test suite failed to notice it.
cp "$ROOT/rca_engine/rules/default_rules.json" "$TMPDIR/rules_original.json"
rca_engine_read_json "$TMPDIR" "
import json
data = json.load(open('rules_original.json', encoding='utf-8'))
for rule in data['rules']:
    if rule['rule_id'] == 'RULE-OS-PROCESS-LIMIT-001':
        rule['min_independent_sources'] = 999
        for cond in rule['supporting_conditions']:
            if cond['attribute'] == 'nproc_utilization_percent':
                cond['value'] = 999.0
json.dump(data, open('mutated_rules.json', 'w'), indent=2)
" > /dev/null

rca_engine_run "$TMPDIR" "fixture.json" "mutated_rules.json" "" "mutated.json"
[ "$RCA_ENGINE_RUN_RC" -eq 0 ] || { echo "[FAIL] mutated run exit $RCA_ENGINE_RUN_RC"; exit 1; }
MUTATED_STATUS=$(rca_engine_read_json "$TMPDIR" "
import json
r = json.load(open('mutated.json'))
print(r['root_cause']['completeness'])
")

if [ "$MUTATED_STATUS" = "CONFIRMED" ]; then
  echo "[FAIL] MUTATION TEST INEFFECTIVE: la regla mutada (umbral inalcanzable) todavía produjo CONFIRMED"
  echo "       esto significa que la suite NO detectaría un defecto real de causalidad"
  FAIL=1
else
  echo "[PASS] MUTATION TEST EFFECTIVE: la regla mutada produjo '$MUTATED_STATUS' (no CONFIRMED) —"
  echo "       la suite es sensible a un defecto de causalidad introducido deliberadamente"
fi

# The real, tracked rules file must be completely untouched by this test — the mutation only ever
# existed at $TMPDIR/mutated_rules.json, removed by the EXIT trap.
if [ -f "$ROOT/rca_engine/rules/default_rules.json" ] && ! grep -q '"min_independent_sources": 999' "$ROOT/rca_engine/rules/default_rules.json"; then
  echo "[PASS] rca_engine/rules/default_rules.json permanece sin modificar (la mutación sólo existió en TMPDIR)"
else
  echo "[FAIL] rca_engine/rules/default_rules.json fue modificado por este test"
  FAIL=1
fi

exit $FAIL
