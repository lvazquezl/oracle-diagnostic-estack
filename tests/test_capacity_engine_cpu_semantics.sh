#!/usr/bin/env bash
# PHASE 10 — FORECASTING EXECUTION & NUMERICAL VALIDATION HARDENING, sección 10/caso 15
# (# 158 del prompt): threshold condicional, sin "CPU exhaustion date".
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
    ts = start + timedelta(days=day, hours=12)
    samples.append({'target_id': 'T-CPU', 'technology': 'linux', 'resource_type': 'cpu',
        'metric_name': 'used_percent', 'timestamp': ts.isoformat(), 'total_capacity': 100.0,
        'used_capacity': 30.0 + 0.5*day, 'unit': 'percentage', 'source_id': 'fixture', 'evidence_id': 'EVD-CPU-1'})

policy = {'minimum_samples': 10, 'minimum_history_days': 10, 'preferred_history_days': 30}
r = run_capacity_forecast(samples, policy=policy, thresholds={'warning_percent': 80.0}, resource_type_hint='cpu')

# threshold crossing SI se calcula (proyeccion condicional de utilizacion sostenida) ...
t = r.thresholds[0]
assert t['status'] in ('DATE_ESTIMATED', 'NOT_EXPECTED_WITHIN_HORIZON', 'ALREADY_EXCEEDED'), t

# ... pero NUNCA como campo de 'exhaustion_date'/'saturation_date' -- el esquema de ThresholdResult
# no tiene ese campo en absoluto, y el ForecastResult no expone ninguna clave con ese nombre.
result_dict = r.to_dict()
def _walk(obj):
    if isinstance(obj, dict):
        for k, v in obj.items():
            assert 'exhaustion' not in k.lower(), k
            assert 'saturation_date' not in k.lower(), k
            _walk(v)
    elif isinstance(obj, list):
        for item in obj:
            _walk(item)
_walk(result_dict)

# la limitacion explicita de semantica CPU debe estar presente.
assert any('exhaustion' in lim.lower() or 'conditional' in lim.lower() or 'utilization trend' in lim.lower()
           for lim in r.limitations), r.limitations

print('ENGINE_OK')
")
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] capacity_engine calcula threshold crossing condicional para CPU y nunca expone un campo de exhaustion/saturation date"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi
exit $FAIL
