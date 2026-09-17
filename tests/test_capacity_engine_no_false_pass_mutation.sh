#!/usr/bin/env bash
# PHASE 10 — FORECASTING EXECUTION & NUMERICAL VALIDATION HARDENING, sección 10 (# 164 del
# prompt): "Requisito anti-falso-PASS: introduce una prueba de mutación sencilla o un caso
# negativo equivalente que demuestre que alterar deliberadamente la pendiente/forecast calculado
# hace fallar el test."
#
# Enfoque: correr el motor sobre DOS datasets sintéticos con pendientes conocidas y DISTINTAS, y
# comprobar que el slope devuelto DIFIERE en consecuencia. Una implementación que siempre
# devolviera un valor constante/hardcodeado (ignorando el input real) haría fallar esta prueba —
# a diferencia de un test que sólo comparara contra un fixture pre-calculado, que un motor
# "siempre-devuelve-lo-mismo" también podría pasar por casualidad.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys; sys.path.insert(0, '.')
from datetime import datetime, timedelta, timezone
from capacity_engine.engine import run_capacity_forecast

start = datetime(2026, 1, 1, tzinfo=timezone.utc)

def make(slope_per_day, n=90):
    out = []
    for day in range(n):
        ts = start + timedelta(days=day, hours=12)
        out.append({'target_id': 'T-MUT', 'technology': 'linux', 'resource_type': 'filesystem',
            'metric_name': 'used_bytes', 'timestamp': ts.isoformat(), 'total_capacity': 1_000_000.0,
            'used_capacity': 100.0 + slope_per_day*day, 'unit': 'bytes', 'source_id': 'fx', 'evidence_id': 'E1'})
    return out

policy = {'minimum_samples': 10, 'minimum_history_days': 10, 'preferred_history_days': 60}

r_slow = run_capacity_forecast(make(1.0), policy=policy)
r_fast = run_capacity_forecast(make(9.0), policy=policy)
r_neg  = run_capacity_forecast(make(-4.0), policy=policy)

# el motor DEBE reflejar el dato de entrada real, no un valor fijo -- si alguna vez un cambio de
# codigo hiciera que engine.py ignorase la serie y devolviera siempre, por ejemplo, slope=2.0,
# estas tres comparaciones fallarian de inmediato.
assert abs(r_slow.method_parameters['slope'] - 1.0) < 1e-6, r_slow.method_parameters['slope']
assert abs(r_fast.method_parameters['slope'] - 9.0) < 1e-6, r_fast.method_parameters['slope']
assert abs(r_neg.method_parameters['slope'] - (-4.0)) < 1e-6, r_neg.method_parameters['slope']
assert r_slow.method_parameters['slope'] != r_fast.method_parameters['slope']
assert r_slow.method_parameters['slope'] != r_neg.method_parameters['slope']

# lo mismo para el forecast a 1 mes: horizontes DISTINTOS para pendientes DISTINTAS.
assert r_slow.horizons['1m']['expected'] != r_fast.horizons['1m']['expected']
assert r_fast.horizons['1m']['expected'] > r_slow.horizons['1m']['expected']
assert r_neg.diagnostics['trend']['classification'] == 'DECREASING'
assert r_fast.diagnostics['trend']['classification'] == 'INCREASING'

# --- caso adversarial explícito: un motor 'siempre devuelve lo mismo' fallaría aquí ---
class _FakeConstantEngine:
    '''Doble deliberadamente incorrecto para demostrar que ESTE test SI detecta un motor que
    ignora el input -- si run_capacity_forecast se reemplazara por esto, las asserts de arriba
    fallarían.'''
    @staticmethod
    def run_capacity_forecast(*a, **kw):
        class R:
            method_parameters = {'slope': 2.0}
            horizons = {'1m': {'expected': 999.0}}
            diagnostics = {'trend': {'classification': 'STABLE'}}
        return R()

fake_slow = _FakeConstantEngine.run_capacity_forecast(make(1.0), policy=policy)
fake_fast = _FakeConstantEngine.run_capacity_forecast(make(9.0), policy=policy)
# el doble constante FALLA la misma aserción que el motor real pasa -- confirma que la aserción
# tiene poder discriminante real, no es trivialmente satisfecha por cualquier implementación.
constant_engine_would_fail = (fake_slow.method_parameters['slope'] == fake_fast.method_parameters['slope'])
assert constant_engine_would_fail, 'la prueba de mutación no discrimina un motor constante -- revisar'

print('ENGINE_OK')
")
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] capacity_engine refleja el dato de entrada real (pendientes/forecasts distintos para series distintas); confirmado que un motor 'siempre-igual' fallaría esta misma prueba"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi
exit $FAIL
