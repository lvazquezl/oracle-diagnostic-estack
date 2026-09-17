#!/usr/bin/env bash
# PHASE 10 — FORECASTING EXECUTION & NUMERICAL VALIDATION HARDENING, sección 10/caso 5
# (# 148 del prompt): fin de enero, año bisiesto y horizontes 1/3/6 meses.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys; sys.path.insert(0, '.')
from datetime import date
from capacity_engine.stats import add_calendar_months

# Fin de enero -> fin de febrero (no bisiesto): 2026 no es bisiesto.
assert add_calendar_months(date(2026, 1, 31), 1) == date(2026, 2, 28), add_calendar_months(date(2026, 1, 31), 1)
# 2028 SI es bisiesto.
assert add_calendar_months(date(2028, 1, 31), 1) == date(2028, 2, 29), add_calendar_months(date(2028, 1, 31), 1)
# 3 meses desde 31 de enero -> 30 de abril (abril tiene 30 dias).
assert add_calendar_months(date(2026, 1, 31), 3) == date(2026, 4, 30), add_calendar_months(date(2026, 1, 31), 3)
# 6 meses desde 31 de enero -> 31 de julio.
assert add_calendar_months(date(2026, 1, 31), 6) == date(2026, 7, 31), add_calendar_months(date(2026, 1, 31), 6)
# cruce de año: 1 mes desde 31 de diciembre -> 31 de enero del año siguiente.
assert add_calendar_months(date(2026, 12, 31), 1) == date(2027, 1, 31), add_calendar_months(date(2026, 12, 31), 1)
# 29 de febrero bisiesto + 12 meses -> 28 de febrero (no bisiesto).
assert add_calendar_months(date(2028, 2, 29), 12) == date(2029, 2, 28), add_calendar_months(date(2028, 2, 29), 12)

# Ahora vía el motor completo, para confirmar que los horizontes 1/3/6m usan esta aritmetica.
from datetime import datetime, timedelta, timezone
from capacity_engine.engine import run_capacity_forecast
start = datetime(2026, 1, 1, tzinfo=timezone.utc)
samples = []
for day in range(31):  # history_end = 31 de enero
    ts = start + timedelta(days=day, hours=12)
    samples.append({'target_id': 'T-CAL', 'technology': 'linux', 'resource_type': 'filesystem',
        'metric_name': 'used_bytes', 'timestamp': ts.isoformat(), 'total_capacity': 100000.0,
        'used_capacity': 100.0 + 1.0 * day, 'unit': 'bytes', 'source_id': 'fixture', 'evidence_id': 'EVD-CAL-1'})
policy = {'minimum_samples': 10, 'minimum_history_days': 10, 'preferred_history_days': 20}
r = run_capacity_forecast(samples, policy=policy)
assert r.horizons['1m']['date'] == '2026-02-28', r.horizons['1m']['date']
assert r.horizons['3m']['date'] == '2026-04-30', r.horizons['3m']['date']
assert r.horizons['6m']['date'] == '2026-07-31', r.horizons['6m']['date']

print('ENGINE_OK')
")
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] capacity_engine.stats.add_calendar_months y los horizontes 1/3/6m manejan fin de mes, años bisiestos y cruce de año correctamente"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi
exit $FAIL
