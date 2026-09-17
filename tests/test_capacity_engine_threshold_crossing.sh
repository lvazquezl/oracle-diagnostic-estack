#!/usr/bin/env bash
# PHASE 10 — FORECASTING EXECUTION & NUMERICAL VALIDATION HARDENING, sección 10/caso 4
# (# 147 del prompt): cruce conocido por fórmula y estado ALREADY_EXCEEDED separado.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys; sys.path.insert(0, '.')
from datetime import datetime, timedelta, timezone
from capacity_engine.engine import run_capacity_forecast

start = datetime(2026, 1, 1, tzinfo=timezone.utc)

def make(n, used_fn, total=1000.0):
    out = []
    for day in range(n):
        ts = start + timedelta(days=day, hours=12)
        out.append({'target_id': 'T-THR', 'technology': 'linux', 'resource_type': 'filesystem',
            'metric_name': 'used_bytes', 'timestamp': ts.isoformat(), 'total_capacity': total,
            'used_capacity': used_fn(day), 'unit': 'bytes', 'source_id': 'fixture', 'evidence_id': 'EVD-THR-1'})
    return out

policy = {'minimum_samples': 10, 'minimum_history_days': 10, 'preferred_history_days': 60}

# used = 100 + 5*day, total=1000 -> utilization% = (100+5*day)/1000*100 = 10 + 0.5*day
# threshold 80% -> 10 + 0.5*day = 80 -> day = 140 -> ultimo dia observado (x_end)=89
# dias_hasta_cruce = 140 - 89 = 51 dias despues del ultimo dato (dentro del horizonte de 6 meses).
samples = make(90, lambda d: 100.0 + 5.0 * d)
r = run_capacity_forecast(samples, policy=policy, thresholds={'warning_percent': 80.0})
t = r.thresholds[0]
assert t['status'] == 'DATE_ESTIMATED', t
from datetime import date
expected_date = date(2026, 1, 1) + timedelta(days=140)
assert t['estimated_date'] == expected_date.isoformat(), (t['estimated_date'], expected_date.isoformat())

# ALREADY_EXCEEDED: el ultimo valor observado ya supera el umbral.
samples2 = make(90, lambda d: 950.0 + 0.1 * d)  # util% ~ 95-96%, por encima de 90%
r2 = run_capacity_forecast(samples2, policy=policy, thresholds={'critical_percent': 90.0})
t2 = r2.thresholds[0]
assert t2['status'] == 'ALREADY_EXCEEDED', t2
assert t2['estimated_date'] is None, t2

# INVALID_THRESHOLD: umbral fuera de rango (0,100].
r3 = run_capacity_forecast(samples, policy=policy, thresholds={'bad': 150.0})
t3 = r3.thresholds[0]
assert t3['status'] == 'INVALID_THRESHOLD', t3

print('ENGINE_OK')
")
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] capacity_engine calcula la fecha de cruce de umbral por fórmula exacta, distingue ALREADY_EXCEEDED e INVALID_THRESHOLD"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi
exit $FAIL
