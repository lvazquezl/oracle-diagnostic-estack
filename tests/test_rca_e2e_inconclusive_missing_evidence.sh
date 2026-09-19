#!/usr/bin/env bash
# PHASE 11 — RCA EXECUTION & EVIDENCE VALIDATION HARDENING, sección 4 "Caso E2E negativo": un
# ORA/TNS coincidente con un cambio reciente, pero sin mecanismo causal demostrado, produce
# PROBABLE/INCONCLUSIVE/INSUFFICIENT_EVIDENCE — nunca CONFIRMED por proximidad temporal.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/rca_engine_e2e_helpers.sh"
FAIL=0

TMPDIR="$ROOT/tests/.tmp_rca_e2e_inconclusive_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT
cp "$ROOT/tests/fixtures/rca_engine/negative_temporal_proximity.json" "$TMPDIR/fixture.json"

rca_engine_run "$TMPDIR" "fixture.json" "" "" "result.json" "report.md"
if [ "$RCA_ENGINE_RUN_RC" -ne 0 ]; then
  echo "[FAIL] rca_engine.cli terminó con código $RCA_ENGINE_RUN_RC — stderr:"
  sed 's/^/    /' "$RCA_ENGINE_RUN_STDERR_FILE"
  exit 1
fi

OUT=$(rca_engine_read_json "$TMPDIR" "
import json
r = json.load(open('result.json'))
rc = r['root_cause']
assert rc['completeness'] in ('PROBABLE', 'INCONCLUSIVE', 'INSUFFICIENT_EVIDENCE'), rc['completeness']
assert rc['completeness'] != 'CONFIRMED'
assert rc['confirmed_hypothesis_ids'] == []
for h in r['hypotheses']:
    assert h['status'] != 'CONFIRMED', h
assert r['recommendations'] == [], 'no recommendation without a CONFIRMED root cause'
print('ENGINE_OK')
" 2>&1)
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] Symptom + proximidad temporal sin mecanismo nunca produce CONFIRMED"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi

exit $FAIL
