#!/usr/bin/env bash
# PHASE 11 — RCA EXECUTION & EVIDENCE VALIDATION HARDENING, sección 2: rechaza inputs malformados
# con error claro y código de salida distinto de cero — nunca produce un resultado parcial.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/rca_engine_e2e_helpers.sh"
FAIL=0

TMPDIR="$ROOT/tests/.tmp_rca_invalid_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT
cp "$ROOT/tests/fixtures/rca_engine/invalid_missing_required_field.json" "$TMPDIR/fixture.json"

rca_engine_run "$TMPDIR" "fixture.json" "" "" "result.json"
if [ "$RCA_ENGINE_RUN_RC" -eq 0 ]; then
  echo "[FAIL] el CLI terminó con exit 0 sobre un fixture con 'target_id' faltante (debía rechazarlo)"
  FAIL=1
else
  grep -qi "target_id" "$RCA_ENGINE_RUN_STDERR_FILE" \
    && echo "[PASS] el CLI rechaza el input malformado con exit $RCA_ENGINE_RUN_RC y mensaje claro" \
    || { echo "[FAIL] exit no-cero pero sin mensaje claro sobre el campo faltante"; FAIL=1; }
fi
[ -f "$TMPDIR/result.json" ] && { echo "[FAIL] no debía generarse result.json sobre input inválido"; FAIL=1; }

# A second, structurally-invalid fixture (not even valid JSON) must also fail non-zero.
echo '{ this is not valid json' > "$TMPDIR/broken.json"
rca_engine_run "$TMPDIR" "broken.json" "" "" "result2.json"
[ "$RCA_ENGINE_RUN_RC" -ne 0 ] \
  && echo "[PASS] JSON sintácticamente inválido también produce exit no-cero" \
  || { echo "[FAIL] JSON inválido no produjo exit no-cero"; FAIL=1; }

exit $FAIL
