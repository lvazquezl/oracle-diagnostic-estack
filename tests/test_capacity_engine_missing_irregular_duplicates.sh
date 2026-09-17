#!/usr/bin/env bash
# PHASE 10 — FORECASTING EXECUTION & NUMERICAL VALIDATION HARDENING, sección 10/caso 7
# (# 150 del prompt): cobertura y agregación reproducibles; rechazar o degradar según policy.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys; sys.path.insert(0, '.')
from datetime import datetime, timedelta, timezone
from capacity_engine.engine import run_capacity_forecast

start = datetime(2026, 1, 1, tzinfo=timezone.utc)
samples = []
for day in range(60):
    if day % 5 == 0:
        continue  # gaps: falta 1 de cada 5 dias
    ts = start + timedelta(days=day, hours=12, minutes=(day * 7) % 60)  # muestreo irregular
    samples.append({'target_id': 'T-IRR', 'technology': 'linux', 'resource_type': 'filesystem',
        'metric_name': 'used_bytes', 'timestamp': ts.isoformat(), 'total_capacity': 10000.0,
        'used_capacity': 100.0 + 2.0 * day, 'unit': 'bytes', 'source_id': 'fixture', 'evidence_id': 'EVD-IRR-1'})
    # duplicado exacto (mismo timestamp) para algunos dias
    if day % 10 == 1:
        samples.append(dict(samples[-1]))

policy = {'minimum_samples': 10, 'minimum_history_days': 10, 'preferred_history_days': 90}
r = run_capacity_forecast(samples, policy=policy)

present_days = [day for day in range(60) if day % 5 != 0]
expected_gap_days = (present_days[-1] - present_days[0] + 1) - len(present_days)  # gaps WITHIN the observed span only
assert r.daily_aggregate_count == len(present_days), (r.daily_aggregate_count, len(present_days))
assert r.diagnostics['data_quality']['gap_count'] == expected_gap_days, (r.diagnostics['data_quality'], expected_gap_days)
assert r.diagnostics['data_quality']['duplicate_count'] > 0, r.diagnostics['data_quality']
assert r.data_quality in ('ACCEPTABLE', 'DEGRADED', 'GOOD'), r.data_quality  # nunca INVALID por esto solo

# Reproducibilidad de la agregacion: correr dos veces produce el mismo daily_aggregate_count y
# coverage (agregacion determinista pese al muestreo irregular).
r2 = run_capacity_forecast(samples, policy=policy)
assert r.daily_aggregate_count == r2.daily_aggregate_count
assert r.diagnostics['data_quality']['coverage'] == r2.diagnostics['data_quality']['coverage']

print('ENGINE_OK')
")
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] capacity_engine calcula gap_count/duplicate_count correctamente y agrega de forma reproducible pese a muestreo irregular"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi
exit $FAIL
