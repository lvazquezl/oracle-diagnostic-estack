#!/usr/bin/env bash
# PHASE 10 — FORECASTING EXECUTION & NUMERICAL VALIDATION HARDENING, sección 10/caso 9
# (# 152 del prompt): cambio de total_capacity; segmentación y rechazo de forecast si el
# segmento posterior no alcanza mínimo.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys; sys.path.insert(0, '.')
from datetime import datetime, timedelta, timezone
from capacity_engine.engine import run_capacity_forecast

start = datetime(2026, 1, 1, tzinfo=timezone.utc)

def series(pre_days, post_days, pre_total, post_total):
    out = []
    for day in range(pre_days):
        ts = start + timedelta(days=day, hours=12)
        out.append({'target_id': 'T-RSZ', 'technology': 'linux', 'resource_type': 'filesystem',
            'metric_name': 'used_bytes', 'timestamp': ts.isoformat(), 'total_capacity': pre_total,
            'used_capacity': 100.0 + 2.0*day, 'unit': 'bytes', 'source_id': 'fixture', 'evidence_id': 'EVD-RSZ-1'})
    for day in range(pre_days, pre_days + post_days):
        ts = start + timedelta(days=day, hours=12)
        out.append({'target_id': 'T-RSZ', 'technology': 'linux', 'resource_type': 'filesystem',
            'metric_name': 'used_bytes', 'timestamp': ts.isoformat(), 'total_capacity': post_total,
            'used_capacity': 200.0 + 3.0*(day-pre_days), 'unit': 'bytes', 'source_id': 'fixture', 'evidence_id': 'EVD-RSZ-1'})
    return out

policy = {'minimum_samples': 30, 'minimum_history_days': 30, 'preferred_history_days': 60}

# Segmento posterior suficiente (60 dias >= minimum_history_days=30).
samples_ok = series(30, 60, 1000.0, 5000.0)
r = run_capacity_forecast(samples_ok, policy=policy)
assert len(r.capacity_events) == 1, r.capacity_events
ev = r.capacity_events[0]
assert ev['event_type'] == 'capacity_resize', ev
assert ev['old_total'] == 1000.0 and ev['new_total'] == 5000.0, ev
assert r.sample_count == 60, r.sample_count               # solo el segmento posterior
assert abs(r.method_parameters['slope'] - 3.0) < 1e-6, r.method_parameters['slope']  # slope del segmento posterior, no mezclado
assert r.data_quality != 'INSUFFICIENT', r.data_quality

# Segmento posterior insuficiente (10 dias < minimum_history_days=30) -> INSUFFICIENT_HISTORY,
# nunca mezclar con el segmento anterior para 'completar' la historia.
samples_short = series(60, 10, 1000.0, 5000.0)
r2 = run_capacity_forecast(samples_short, policy=policy)
assert r2.sample_count == 10, r2.sample_count
assert r2.data_quality == 'INSUFFICIENT', r2.data_quality
assert r2.method == 'INSUFFICIENT_HISTORY', r2.method

print('ENGINE_OK')
")
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] capacity_engine segmenta en el evento de resize, usa sólo el segmento posterior, y declara INSUFFICIENT_HISTORY cuando ese segmento es corto"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi
exit $FAIL
