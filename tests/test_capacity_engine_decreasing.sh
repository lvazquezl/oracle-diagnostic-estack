#!/usr/bin/env bash
# PHASE 10 — FORECASTING EXECUTION & NUMERICAL VALIDATION HARDENING, sección 10/caso 3
# (# 146 del prompt): pendiente negativa; nunca fecha positiva de agotamiento.
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
        'target_id': 'T-DEC', 'technology': 'linux', 'resource_type': 'filesystem',
        'metric_name': 'used_bytes', 'timestamp': ts.isoformat(),
        'total_capacity': 10000.0, 'used_capacity': 1000.0 - 3.0 * day, 'unit': 'bytes',
        'source_id': 'fixture', 'evidence_id': 'EVD-DEC-1',
    })

policy = {'minimum_samples': 10, 'minimum_history_days': 10, 'preferred_history_days': 60}
thresholds = {'warning_percent': 80.0}
r = run_capacity_forecast(samples, policy=policy, thresholds=thresholds)

assert r.diagnostics['trend']['classification'] == 'DECREASING', r.diagnostics['trend']
assert abs(r.method_parameters['slope'] - (-3.0)) < 1e-6, r.method_parameters['slope']

# Nunca una fecha de agotamiento/cruce con pendiente negativa hacia un umbral por ENCIMA del
# valor actual -- el umbral (80% = 8000 bytes) esta muy por encima del used actual y decreciendo,
# jamas se cruza.
t = r.thresholds[0]
assert t['status'] == 'NOT_EXPECTED_WITHIN_HORIZON', t
assert t['estimated_date'] is None, t

print('ENGINE_OK')
")
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] capacity_engine clasifica DECREASING con slope negativo exacto y nunca produce fecha de agotamiento futura"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi
exit $FAIL
