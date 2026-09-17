#!/usr/bin/env bash
# PHASE 10 — FORECASTING EXECUTION & NUMERICAL VALIDATION HARDENING, sección 10/caso 8
# (# 151 del prompt): detección y exclusión si habilitada, con trazabilidad; comparar método
# con/sin exclusión.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys; sys.path.insert(0, '.')
from datetime import datetime, timedelta, timezone
from capacity_engine.engine import run_capacity_forecast
from capacity_engine.stats import robust_outliers

start = datetime(2026, 1, 1, tzinfo=timezone.utc)
samples = []
for day in range(60):
    ts = start + timedelta(days=day, hours=12)
    used = 100.0 + 2.0 * day
    if day == 30:
        used = 5000.0  # outlier transitorio aislado
    samples.append({'target_id': 'T-OUT', 'technology': 'linux', 'resource_type': 'filesystem',
        'metric_name': 'used_bytes', 'timestamp': ts.isoformat(), 'total_capacity': 100000.0,
        'used_capacity': used, 'unit': 'bytes', 'source_id': 'fixture', 'evidence_id': 'EVD-OUT-1'})

policy = {'minimum_samples': 10, 'minimum_history_days': 10, 'preferred_history_days': 40}
r = run_capacity_forecast(samples, policy=policy)

# deteccion directa via stats.robust_outliers sobre la serie usada
values = [100.0 + 2.0*d if d != 30 else 5000.0 for d in range(60)]
idx = robust_outliers(values)
assert 30 in idx, idx

# el motor debe haber excluido el dia 30 del ajuste y trazarlo
assert any('2026-01-31' in day for day in r.diagnostics['trend']['excluded_days']), r.diagnostics['trend']['excluded_days']
assert any('outlier' in lim.lower() for lim in r.limitations), r.limitations

# comparacion con/sin exclusion: el slope CON exclusion debe estar mucho mas cerca de 2.0 que
# un ajuste ingenuo que incluyera el outlier.
slope_with_exclusion = r.method_parameters['slope']
assert abs(slope_with_exclusion - 2.0) < 0.5, slope_with_exclusion

from capacity_engine.stats import ols_fit
xs_all = list(range(60))
fit_naive = ols_fit(xs_all, values)  # sin exclusion
assert abs(fit_naive['slope'] - 2.0) > abs(slope_with_exclusion - 2.0), (fit_naive['slope'], slope_with_exclusion)

print('ENGINE_OK')
")
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] capacity_engine detecta, excluye y traza el outlier, mejorando el ajuste respecto a un fit ingenuo que lo incluye"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi
exit $FAIL
