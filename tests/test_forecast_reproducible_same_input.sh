#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 83/69 (# 1543-1551 del prompt).
# PHASE 10 — FORECASTING EXECUTION & NUMERICAL VALIDATION HARDENING (# 155, # 162 del prompt):
# endurecido con ejecución real del motor dos veces sobre los mismos datos/policy/as-of y
# comparación exacta de salidas (excluyendo sólo generated_at, metadata de auditoría de reloj).
# Los chequeos documentales originales se conservan abajo, claramente etiquetados.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys; sys.path.insert(0, '.')
from datetime import datetime, timedelta, timezone
from capacity_engine.engine import run_capacity_forecast

start = datetime(2026, 1, 1, tzinfo=timezone.utc)
samples = []
for day in range(90):
    ts = start + timedelta(days=day, hours=12)
    samples.append({
        'target_id': 'T-REPRO', 'technology': 'linux', 'resource_type': 'filesystem',
        'metric_name': 'used_bytes', 'timestamp': ts.isoformat(),
        'total_capacity': 100000.0, 'used_capacity': 100.0 + 2.0 * day, 'unit': 'bytes',
        'source_id': 'fixture', 'evidence_id': 'EVD-REPRO-1',
    })

policy = {'minimum_samples': 10, 'minimum_history_days': 10, 'preferred_history_days': 60}
thresholds = {'warning_percent': 80.0}

r1 = run_capacity_forecast(samples, policy=policy, thresholds=thresholds, as_of='2026-06-01T00:00:00+00:00')
r2 = run_capacity_forecast(samples, policy=policy, thresholds=thresholds, as_of='2026-06-01T00:00:00+00:00')

d1 = r1.to_dict()
d2 = r2.to_dict()

# generated_at es metadata de auditoria de reloj -- explicitamente excluida de la comparacion de
# reproducibilidad (# 130, # 155 del prompt: 'no afectar resultados numericos/reproducibilidad').
assert 'generated_at' in d1 and 'generated_at' in d2
d1.pop('generated_at'); d2.pop('generated_at')

assert d1 == d2, 'dos ejecuciones con los mismos datos/policy/as_of deben producir resultados identicos'
assert r1.algorithm_version == r2.algorithm_version == 'capacity_engine.forecast.linear_ols/1.0.0'
assert r1.contract_version == r2.contract_version

# mutacion negativa: cambiar el as_of no debe alterar el forecast (nunca afecta el calculo), pero
# SI puede alterar freshness_hours si se calculase -- confirmamos que el resultado numerico central
# (horizontes/slope) permanece igual con un as_of distinto.
r3 = run_capacity_forecast(samples, policy=policy, thresholds=thresholds, as_of='2026-08-01T00:00:00+00:00')
assert r3.method_parameters['slope'] == r1.method_parameters['slope']
assert r3.horizons['1m']['expected'] == r1.horizons['1m']['expected']

print('ENGINE_OK')
")
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] capacity_engine produce salidas idénticas en dos ejecuciones con los mismos datos/policy/as_of (excluyendo generated_at)"
else
  echo "[FAIL] la reproducibilidad numérica del motor falló: $OUT"
  FAIL=1
fi

# --- Verificación documental (skill) — se conserva, no reemplaza la ejecución real ---
S="$ROOT/skills/capacity/forecasting/SKILL.md"
[ -f "$S" ] || { echo "[FAIL] falta $S"; FAIL=1; }
if [ -f "$S" ]; then
  grep -q 'forecast_contract_version' "$S" && echo "[PASS] (documental) declara forecast_contract_version" || { echo "[FAIL] falta forecast_contract_version"; FAIL=1; }
  grep -q 'cambios matemáticos alteren reportes' "$S" && echo "[PASS] (documental) forecast_contract_version evita que cambios matemáticos alteren reportes previos sin trazabilidad" || { echo "[FAIL] falta la disciplina de trazabilidad"; FAIL=1; }
fi

exit $FAIL
