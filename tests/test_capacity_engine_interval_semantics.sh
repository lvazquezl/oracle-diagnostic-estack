#!/usr/bin/env bash
# PHASE 10 — FORECASTING EXECUTION & NUMERICAL VALIDATION HARDENING, sección 10/caso 13
# (# 156 del prompt): validar orden lower <= expected <= upper, supuestos y fallback si no son
# estimables; no confundir confianza con probabilidad.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys; sys.path.insert(0, '.')
from datetime import datetime, timedelta, timezone
from capacity_engine.engine import run_capacity_forecast
from capacity_engine.stats import ols_fit, prediction_interval

start = datetime(2026, 1, 1, tzinfo=timezone.utc)
samples = []
import random
rnd = random.Random(42)
for day in range(90):
    ts = start + timedelta(days=day, hours=12)
    noise = rnd.uniform(-3.0, 3.0)
    samples.append({'target_id': 'T-INT', 'technology': 'linux', 'resource_type': 'filesystem',
        'metric_name': 'used_bytes', 'timestamp': ts.isoformat(), 'total_capacity': 1_000_000.0,
        'used_capacity': 100.0 + 2.0*day + noise, 'unit': 'bytes', 'source_id': 'fixture', 'evidence_id': 'EVD-INT-1'})

policy = {'minimum_samples': 10, 'minimum_history_days': 10, 'preferred_history_days': 60}
r = run_capacity_forecast(samples, policy=policy)
for k in ('1m', '3m', '6m'):
    h = r.horizons[k]
    if h['lower'] is not None and h['upper'] is not None:
        assert h['lower'] <= h['expected'] <= h['upper'], (k, h)
        assert h['upper'] > h['lower'], (k, h)  # intervalo con ancho positivo, nunca degenerado con ruido presente

# el intervalo se ensancha con el horizonte (mas lejos del historico -> mas incertidumbre)
w1 = r.horizons['1m']['upper'] - r.horizons['1m']['lower']
w6 = r.horizons['6m']['upper'] - r.horizons['6m']['lower']
assert w6 > w1, (w1, w6)

# metodo documentado explicitamente como aproximacion normal, nunca presentado como Student-t exacto
assert r.method_parameters['interval_method'] == 'normal_approximation_z95'
assert 'normal approximation' in r.diagnostics['interval_note'].lower()

# fallback NOT_ESTIMABLE: con solo 2 puntos no hay grados de libertad para un intervalo.
fit2 = ols_fit([0, 1], [10.0, 20.0])
assert prediction_interval(fit2, 5) is None

# con 1 punto, ni siquiera se puede ajustar una recta -- ValueError, nunca un numero inventado.
raised = False
try:
    ols_fit([0], [10.0])
except ValueError:
    raised = True
assert raised

# la confianza es un estado categorico (HIGH/MEDIUM/LOW/INSUFFICIENT), nunca un numero de
# probabilidad -- comprobamos el tipo, no un valor numerico.
assert r.confidence in ('HIGH', 'MEDIUM', 'LOW', 'INSUFFICIENT'), r.confidence
assert not isinstance(r.confidence, (int, float))

print('ENGINE_OK')
")
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] capacity_engine produce intervalos lower<=expected<=upper, crecientes con el horizonte, documentados como aproximación normal, con fallback explícito cuando no son estimables"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi
exit $FAIL
