#!/usr/bin/env bash
# PHASE 11 — RCA EXECUTION & EVIDENCE VALIDATION HARDENING, sección 4.7: dos hipótesis plausibles
# sin evidencia diferenciadora producen un resultado explícitamente inconcluso — nunca se elige un
# ganador forzado entre RLIMIT_NPROC y cgroup pids.max cuando ambas tienen exactamente el mismo
# soporte (1 fuente independiente cada una, sin contradicción).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/rca_engine_e2e_helpers.sh"
FAIL=0

TMPDIR="$ROOT/tests/.tmp_rca_competing_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT
cp "$ROOT/tests/fixtures/rca_engine/competing_hypotheses.json" "$TMPDIR/fixture.json"

rca_engine_run "$TMPDIR" "fixture.json" "" "" "result.json"
[ "$RCA_ENGINE_RUN_RC" -eq 0 ] || { echo "[FAIL] exit $RCA_ENGINE_RUN_RC"; sed 's/^/    /' "$RCA_ENGINE_RUN_STDERR_FILE"; exit 1; }

OUT=$(rca_engine_read_json "$TMPDIR" "
import json
r = json.load(open('result.json'))
rc = r['root_cause']
assert rc['completeness'] == 'INCONCLUSIVE', rc
assert len(rc['competing_hypothesis_ids']) == 2, rc['competing_hypothesis_ids']
assert set(rc['competing_hypothesis_ids']) == {
    'HYP-INC-20260311-006-RULE-OS-PROCESS-LIMIT-001',
    'HYP-INC-20260311-006-RULE-OS-PROCESS-LIMIT-CGROUP-001',
}, rc['competing_hypothesis_ids']
assert rc['confirmed_hypothesis_ids'] == []
assert r['recommendations'] == []
print('ENGINE_OK')
" 2>&1)
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] Dos hipótesis igualmente soportadas producen INCONCLUSIVE, sin ganador forzado"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi

exit $FAIL
