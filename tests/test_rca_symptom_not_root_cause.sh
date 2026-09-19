#!/usr/bin/env bash
# PHASE 11 — RCA EXECUTION & EVIDENCE VALIDATION HARDENING, sección 0/4.5: un síntoma aislado
# (ORA-12537 sin ninguna otra evidencia) nunca se eleva a CONFIRMED ni siquiera a SUPPORTED —
# queda INSUFFICIENT_EVIDENCE, el propio síntoma nunca es su propia evidencia de soporte.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/rca_engine_e2e_helpers.sh"
FAIL=0

TMPDIR="$ROOT/tests/.tmp_rca_symptom_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT
cp "$ROOT/tests/fixtures/rca_engine/symptom_not_root_cause.json" "$TMPDIR/fixture.json"

rca_engine_run "$TMPDIR" "fixture.json" "" "" "result.json"
[ "$RCA_ENGINE_RUN_RC" -eq 0 ] || { echo "[FAIL] exit $RCA_ENGINE_RUN_RC"; sed 's/^/    /' "$RCA_ENGINE_RUN_STDERR_FILE"; exit 1; }

OUT=$(rca_engine_read_json "$TMPDIR" "
import json
r = json.load(open('result.json'))
h = next(h for h in r['hypotheses'] if h['rule_id'] == 'RULE-NET-LISTENER-HANG-001')
assert h['supporting_evidence_ids'] == [], h['supporting_evidence_ids']
assert h['independent_source_count'] == 0
assert h['status'] == 'INSUFFICIENT_EVIDENCE', h['status']
assert r['root_cause']['completeness'] == 'INSUFFICIENT_EVIDENCE', r['root_cause']
print('ENGINE_OK')
" 2>&1)
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] Un síntoma aislado nunca se eleva más allá de INSUFFICIENT_EVIDENCE"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi

exit $FAIL
