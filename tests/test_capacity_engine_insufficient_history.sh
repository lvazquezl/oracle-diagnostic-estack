#!/usr/bin/env bash
# PHASE 10 — FORECASTING EXECUTION & NUMERICAL VALIDATION HARDENING, sección 10/caso 6
# (# 149 del prompt): filas duplicadas concentradas en pocos días NO equivalen a historia válida.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys; sys.path.insert(0, '.')
from datetime import datetime, timedelta, timezone
from capacity_engine.engine import run_capacity_forecast

start = datetime(2026, 1, 1, tzinfo=timezone.utc)
samples = []
# 200 muestras, pero todas concentradas en solo 3 dias distintos (cada dia con muchas horas
# distintas) -- nunca debe contar como 200 dias de historia.
for i in range(200):
    day = i % 3
    hour = (i // 3) % 24
    ts = start + timedelta(days=day, hours=hour, minutes=(i % 60))
    samples.append({'target_id': 'T-INSUF', 'technology': 'linux', 'resource_type': 'filesystem',
        'metric_name': 'used_bytes', 'timestamp': ts.isoformat(), 'total_capacity': 10000.0,
        'used_capacity': 100.0 + i * 0.1, 'unit': 'bytes', 'source_id': 'fixture', 'evidence_id': 'EVD-INSUF-1'})

policy = {'minimum_samples': 30, 'minimum_history_days': 30, 'preferred_history_days': 90}
r = run_capacity_forecast(samples, policy=policy, thresholds={'warning_percent': 80.0})

assert r.sample_count == 200, r.sample_count           # las 200 muestras son validas individualmente
assert r.daily_aggregate_count == 3, r.daily_aggregate_count  # pero solo 3 dias distintos
assert r.data_quality == 'INSUFFICIENT', r.data_quality
assert r.confidence == 'INSUFFICIENT', r.confidence
assert r.method == 'INSUFFICIENT_HISTORY', r.method
for k in ('1m', '3m', '6m'):
    assert r.horizons[k]['status'] == 'INSUFFICIENT_EVIDENCE', (k, r.horizons[k])
    assert r.horizons[k]['expected'] is None, (k, r.horizons[k])
assert r.thresholds[0]['status'] == 'INSUFFICIENT_EVIDENCE', r.thresholds[0]
assert any('minimum_samples' in lim or 'minimum_history_days' in lim for lim in r.limitations) or \
       any('minimum_samples' in reason or 'minimum_history_days' in reason for reason in r.diagnostics['data_quality']['reasons'])

print('ENGINE_OK')
")
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] capacity_engine distingue sample_count (200) de daily_aggregate_count (3) y nunca produce forecast desde historia insuficiente"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi
exit $FAIL
