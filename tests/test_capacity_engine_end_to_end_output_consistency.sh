#!/usr/bin/env bash
# PHASE 10 — CLI END-TO-END & CROSS-PLATFORM PATH HARDENING (# 5, # 56-58 del prompt): validación
# matemática y de trazabilidad más profunda del recorrido fixture->CLI->JSON->Markdown -- método,
# pendiente con tolerancia explícita, contrato/versión de algoritmo, horizontes 1/3/6m poblados,
# consistencia numérica JSON<->reporte, e IDs de evidencia preservados sin secretos.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/capacity_engine_e2e_helpers.sh"
FAIL=0

TMPDIR="$ROOT/tests/.tmp_capacity_e2e_consistency_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT

capacity_engine_write_linear_fixture "$TMPDIR" "fixture.json" 4.0 1000.0 90
[ $? -eq 0 ] || { echo "[FAIL] FIXTURE_GENERATION_FAILED"; exit 1; }
echo '{"warning_percent": 80.0}' > "$TMPDIR/thresholds.json"
echo '{"minimum_samples": 10, "minimum_history_days": 10, "preferred_history_days": 60}' > "$TMPDIR/policy.json"

capacity_engine_run "$TMPDIR" "fixture.json" "policy.json" "thresholds.json" "result.json" "report.md"
if [ "$CAPACITY_ENGINE_RUN_RC" -ne 0 ]; then
  echo "[FAIL] capacity_engine.cli terminó con código $CAPACITY_ENGINE_RUN_RC — stderr:"
  sed 's/^/    /' "$CAPACITY_ENGINE_RUN_STDERR_FILE"
  exit 1
fi
[ -f "$TMPDIR/result.json" ] && [ -f "$TMPDIR/report.md" ] || { echo "[FAIL] faltan artefactos de salida"; exit 1; }

OUT=$(cd "$TMPDIR" && python3 -c "
import json
result = json.load(open('result.json'))
report = open('report.md', encoding='utf-8').read()

# metodo y version de algoritmo
assert result['method'] == 'linear_regression', result['method']
assert result['algorithm_version'] == 'capacity_engine.forecast.linear_ols/1.0.0', result['algorithm_version']
assert result['contract_version'] == '1.0.0', result['contract_version']

# pendiente con tolerancia explicita (no exacta a ciegas -- la serie es sintetica sin ruido, pero
# se documenta la tolerancia usada, nunca comparacion de string).
slope = result['method_parameters']['slope']
TOLERANCE = 1e-6
assert abs(slope - 4.0) < TOLERANCE, (slope, TOLERANCE)

# los 3 horizontes deben estar poblados con fecha Y valor -- nunca None silencioso cuando el
# metodo es linear_regression con historia suficiente.
for key in ('1m', '3m', '6m'):
    h = result['horizons'][key]
    assert h['date'] is not None, (key, h)
    assert h['expected'] is not None, (key, h)
    assert h['status'] in ('OK', 'OK_NO_INTERVAL', 'OUT_OF_PHYSICAL_RANGE'), (key, h['status'])

# consistencia numerica JSON <-> reporte Markdown para los 3 horizontes, no solo 1m.
for key in ('1m', '3m', '6m'):
    expected = result['horizons'][key]['expected']
    formatted = f'{expected:,.2f}'
    assert formatted in report, (key, formatted)

# trazabilidad de evidencia -- IDs preservados, nunca perdidos ni transformados en secretos.
assert result['input_evidence_ids'] == ['EVD-E2E-1'], result['input_evidence_ids']
assert result['source_id'] == 'fixture', result['source_id']
assert result['target_id'] == 'T-E2E', result['target_id']

# sin secretos: ningun token que parezca password/key/secret en el JSON ni el reporte.
blob = json.dumps(result) + report
for forbidden in ('password', 'secret', 'api_key', 'private_key'):
    assert forbidden not in blob.lower(), forbidden

print('ENGINE_OK')
" 2>&1)
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] método, versión de algoritmo, horizontes 1/3/6m, consistencia JSON<->Markdown, trazabilidad de evidencia y ausencia de secretos verificados"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi

exit $FAIL
