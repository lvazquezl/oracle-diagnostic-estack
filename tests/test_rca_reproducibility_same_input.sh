#!/usr/bin/env bash
# PHASE 11 — RCA EXECUTION & EVIDENCE VALIDATION HARDENING, sección 2: el pipeline es determinista
# para los mismos inputs/reglas/versiones — dos ejecuciones del mismo fixture producen resultados
# idénticos salvo el campo `generated_at` (metadata de auditoría, nunca parte del razonamiento).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/rca_engine_e2e_helpers.sh"
FAIL=0

TMPDIR="$ROOT/tests/.tmp_rca_repro_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT
cp "$ROOT/tests/fixtures/rca_engine/competing_hypotheses.json" "$TMPDIR/fixture.json"

rca_engine_run "$TMPDIR" "fixture.json" "" "" "result1.json"
[ "$RCA_ENGINE_RUN_RC" -eq 0 ] || { echo "[FAIL] first run exit $RCA_ENGINE_RUN_RC"; exit 1; }
rca_engine_run "$TMPDIR" "fixture.json" "" "" "result2.json"
[ "$RCA_ENGINE_RUN_RC" -eq 0 ] || { echo "[FAIL] second run exit $RCA_ENGINE_RUN_RC"; exit 1; }

OUT=$(rca_engine_read_json "$TMPDIR" "
import json
r1 = json.load(open('result1.json'))
r2 = json.load(open('result2.json'))
r1.pop('generated_at'); r2.pop('generated_at')
assert r1 == r2, 'two runs over the same input diverged (excluding generated_at)'
print('ENGINE_OK')
" 2>&1)
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] Dos ejecuciones del mismo input producen resultados idénticos (excepto generated_at)"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi

exit $FAIL
