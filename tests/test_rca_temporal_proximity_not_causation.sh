#!/usr/bin/env bash
# PHASE 11 — RCA EXECUTION & EVIDENCE VALIDATION HARDENING, sección 0/4.5: la proximidad temporal
# sola sólo aporta correlación — un CONFIG_CHANGE cercano en el tiempo a un síntoma nunca produce
# CONFIRMED sin evidencia de mecanismo causal, aunque el timestamp esté a segundos de distancia.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/rca_engine_e2e_helpers.sh"
FAIL=0

TMPDIR="$ROOT/tests/.tmp_rca_temporal_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT
cp "$ROOT/tests/fixtures/rca_engine/negative_temporal_proximity.json" "$TMPDIR/fixture.json"

rca_engine_run "$TMPDIR" "fixture.json" "" "" "result.json"
[ "$RCA_ENGINE_RUN_RC" -eq 0 ] || { echo "[FAIL] exit $RCA_ENGINE_RUN_RC"; sed 's/^/    /' "$RCA_ENGINE_RUN_STDERR_FILE"; exit 1; }

OUT=$(rca_engine_read_json "$TMPDIR" "
import json
r = json.load(open('result.json'))
# EVD-2 (CONFIG_CHANGE) is only 2m07s before the symptom EVD-1 — close in time, but the rules
# catalog has no condition that treats mere temporal proximity as supporting evidence, so it must
# never appear in any hypothesis' supporting_evidence_ids.
for h in r['hypotheses']:
    assert 'EVD-2' not in h['supporting_evidence_ids'], (
        'CONFIG_CHANGE evidence used as supporting evidence purely by temporal proximity: ' + str(h)
    )
assert r['root_cause']['completeness'] != 'CONFIRMED'
print('ENGINE_OK')
" 2>&1)
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] Un CONFIG_CHANGE cercano en el tiempo nunca se cuenta como evidencia de soporte por sí solo"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi

exit $FAIL
