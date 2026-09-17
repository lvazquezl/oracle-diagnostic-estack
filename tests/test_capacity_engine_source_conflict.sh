#!/usr/bin/env bash
# PHASE 10 — FORECASTING EXECUTION & NUMERICAL VALIDATION HARDENING, sección 10/caso 10
# (# 153 del prompt): dos fuentes discrepantes; prohibir promedio ciego.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys; sys.path.insert(0, '.')
from datetime import datetime, timedelta, timezone
from capacity_engine.normalization import normalize_samples
from capacity_engine.aggregation import aggregate_daily
from capacity_engine.reconciliation import reconcile_daily_series

start = datetime(2026, 1, 1, tzinfo=timezone.utc)

def mk_source(source_id, used_fn, n=20):
    raw = []
    for day in range(n):
        ts = start + timedelta(days=day, hours=12)
        raw.append({'target_id': 'T-CONF', 'technology': 'linux', 'resource_type': 'cpu',
            'metric_name': 'used_percent', 'timestamp': ts.isoformat(), 'total_capacity': 100.0,
            'used_capacity': used_fn(day), 'unit': 'percentage', 'source_id': source_id, 'evidence_id': 'EVD-'+source_id})
    return raw

a_raw = mk_source('OSEvidence', lambda d: 45.0)
b_raw = mk_source('Site24x7', lambda d: 78.0)   # discrepancia grande y constante -> conflicto

norm_a = normalize_samples(a_raw)
norm_b = normalize_samples(b_raw)
agg_a = aggregate_daily(norm_a['samples'])
agg_b = aggregate_daily(norm_b['samples'])

result = reconcile_daily_series(agg_a, 'OSEvidence', agg_b, 'Site24x7', tolerance=0.05)
assert result['blind_average_used'] is False
assert result['conflict_days'] == len(agg_a) == 20, result
assert result['preferred_source'] == 'OSEvidence'
for c in result['conflicts']:
    assert c['status'] == 'SOURCE_CONFLICT', c
    # nunca se calcula/expone un valor promediado -- solo value_a/value_b por separado
    assert 'blended_value' not in c and 'average' not in c

# Caso de reconciliacion: mismas fuentes, ahora dentro de tolerancia.
b_raw_close = mk_source('Site24x7', lambda d: 46.0)
norm_b2 = normalize_samples(b_raw_close)
agg_b2 = aggregate_daily(norm_b2['samples'])
result2 = reconcile_daily_series(agg_a, 'OSEvidence', agg_b2, 'Site24x7', tolerance=0.05)
assert result2['conflict_days'] == 0, result2
assert result2['reconciled_days'] == 20, result2

print('ENGINE_OK')
")
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] capacity_engine.reconciliation detecta SOURCE_CONFLICT entre dos fuentes discrepantes sin promediar jamás, y reconcilia cuando están dentro de tolerancia"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi
exit $FAIL
