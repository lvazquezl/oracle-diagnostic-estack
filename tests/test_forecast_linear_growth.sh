#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 77/36 (# 861-877 del prompt).
# PHASE 10 — FORECASTING EXECUTION & NUMERICAL VALIDATION HARDENING (# 162 del prompt): endurecido
# con ejecución real del motor (capacity_engine) y assertions numéricas — los chequeos
# documentales originales se conservan abajo, claramente etiquetados, como verificación adicional.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

# --- EJECUCIÓN REAL DEL MOTOR (numérico) ---
OUT=$(cd "$ROOT" && python3 -c "
import sys; sys.path.insert(0, '.')
from datetime import datetime, timedelta, timezone
from capacity_engine.engine import run_capacity_forecast

start = datetime(2026, 1, 1, tzinfo=timezone.utc)
samples = []
for day in range(90):
    ts = start + timedelta(days=day, hours=12)
    used = 100.0 + 2.0 * day  # serie diaria: used = 100 + 2 x dias (# 144 del prompt)
    samples.append({
        'target_id': 'T-LINEAR', 'technology': 'linux', 'resource_type': 'filesystem',
        'metric_name': 'used_bytes', 'timestamp': ts.isoformat(),
        'total_capacity': 100000.0, 'used_capacity': used, 'unit': 'bytes',
        'source_id': 'fixture', 'evidence_id': 'EVD-LINEAR-1',
    })

policy = {'minimum_samples': 10, 'minimum_history_days': 10, 'preferred_history_days': 60}
r = run_capacity_forecast(samples, policy=policy)

assert r.data_quality in ('GOOD', 'ACCEPTABLE'), r.data_quality
assert r.diagnostics['trend']['classification'] == 'INCREASING', r.diagnostics['trend']
slope = r.method_parameters['slope']
assert abs(slope - 2.0) < 1e-9, ('slope', slope)
intercept = r.method_parameters['intercept']
assert abs(intercept - 100.0) < 1e-6, ('intercept', intercept)
assert r.method == 'linear_regression', r.method
assert r.method_parameters['r_squared'] > 0.999, r.method_parameters['r_squared']

# horizontes: history_end = day 89 (2026-03-31 12:00). +1/+3/+6 meses calendario.
h1, h3, h6 = r.horizons['1m'], r.horizons['3m'], r.horizons['6m']
assert h1['date'] == '2026-04-30', h1
assert h3['date'] == '2026-06-30', h3
assert h6['date'] == '2026-09-30', h6
# expected = intercept + slope * x0, x0 = day_offset del ultimo dia + dias calendario hasta el horizonte
x_end = 89
expected_1m = intercept + slope * (x_end + 30)
assert abs(h1['expected'] - expected_1m) < 1e-6, (h1['expected'], expected_1m)
assert h1['expected'] > 100.0 + 2.0*89, 'el forecast a 1m debe superar el ultimo valor observado (tendencia creciente)'

print('ENGINE_OK')
")
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] capacity_engine calcula slope=2.0, intercept=100.0 y fechas de horizonte correctas sobre una serie sintética used=100+2*dias"
else
  echo "[FAIL] ejecución numérica del motor no produjo el resultado esperado: $OUT"
  FAIL=1
fi

# --- Verificación documental (skills/fixtures) — se conserva, no reemplaza la ejecución real ---
S="$ROOT/skills/capacity/forecasting/SKILL.md"
FX="$ROOT/tests/fixtures/capacity-linear-growth-storage.yaml"
[ -f "$S" ] || { echo "[FAIL] falta $S"; FAIL=1; }
[ -f "$FX" ] || { echo "[FAIL] falta fixture $FX"; FAIL=1; }
if [ -f "$S" ]; then
  grep -q 'linear_regression|robust_linear_regression|moving_average|exponential_smoothing' "$S" && echo "[PASS] (documental) declara los métodos de forecast soportados" || { echo "[FAIL] faltan los métodos de forecast"; FAIL=1; }
fi
if [ -f "$FX" ]; then
  grep -q 'forecast_method: linear_regression' "$FX" && echo "[PASS] (documental) fixture de crecimiento lineal usa linear_regression" || { echo "[FAIL] fixture no declara linear_regression"; FAIL=1; }
fi

exit $FAIL
