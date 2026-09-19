#!/usr/bin/env bash
# PHASE 11 — RCA EXECUTION & EVIDENCE VALIDATION HARDENING, sección 3: un timestamp sin offset
# explícito, o una fuente con clock skew confirmado más allá del umbral, degrada la confianza del
# timeline explícitamente (TIMELINE_CONFIDENCE_DEGRADED) — nunca "corregido" en silencio.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/rca_engine_e2e_helpers.sh"
FAIL=0

TMPDIR="$ROOT/tests/.tmp_rca_skew_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT
cp "$ROOT/tests/fixtures/rca_engine/ambiguous_timestamp_clock_skew.json" "$TMPDIR/fixture.json"

rca_engine_run "$TMPDIR" "fixture.json" "" "" "result.json"
[ "$RCA_ENGINE_RUN_RC" -eq 0 ] || { echo "[FAIL] exit $RCA_ENGINE_RUN_RC"; sed 's/^/    /' "$RCA_ENGINE_RUN_STDERR_FILE"; exit 1; }

OUT=$(rca_engine_read_json "$TMPDIR" "
import json
r = json.load(open('result.json'))
assert r['timeline']['degraded'] is True, r['timeline']
assert len(r['timeline']['degradation_reasons']) >= 2, r['timeline']['degradation_reasons']
joined = ' '.join(r['timeline']['degradation_reasons']).lower()
assert 'naive timestamp' in joined
assert 'clock skew' in joined
# the naive-timestamp item is still normalized as UTC (never dropped), not silently 'fixed' to a
# guessed zone — it is present in the timeline, just flagged.
found_naive = any('EVD-2' in e['evidence_ids'] for e in r['timeline']['events'])
assert found_naive
assert 'timeline_confidence degraded' in ' '.join(r['limitations']).lower()
print('ENGINE_OK')
" 2>&1)
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] Timestamp naive y clock skew confirmado degradan explícitamente la confianza del timeline"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi

exit $FAIL
