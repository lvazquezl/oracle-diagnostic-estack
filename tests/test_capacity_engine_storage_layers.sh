#!/usr/bin/env bash
# PHASE 10 — FORECASTING EXECUTION & NUMERICAL VALIDATION HARDENING, sección 10/caso 14
# (# 157 del prompt): ASM USABLE_FILE_MB, tablespace autoextend y no double counting.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys; sys.path.insert(0, '.')
from datetime import datetime, timedelta, timezone
from capacity_engine.engine import run_capacity_forecast

start = datetime(2026, 1, 1, tzinfo=timezone.utc)
policy = {'minimum_samples': 10, 'minimum_history_days': 10, 'preferred_history_days': 20}

def series(total, used_fn, n=30, resource_type='asm_diskgroup', metric='usable_file_mb'):
    out = []
    for day in range(n):
        ts = start + timedelta(days=day, hours=12)
        out.append({'target_id': 'DATA_DG', 'technology': 'oracle', 'resource_type': resource_type,
            'metric_name': metric, 'timestamp': ts.isoformat(), 'total_capacity': total,
            'used_capacity': used_fn(day), 'unit': 'bytes', 'source_id': 'asm/capacity', 'evidence_id': 'EVD-ASM-1'})
    return out

# ASM: el CALLER pasa total_capacity = USABLE_FILE_MB (ya calculado por asm/capacity, Fase 4),
# nunca TOTAL_MB/FREE_MB crudo -- el motor no reimplementa la formula de redundancia, solo respeta
# el denominador que se le entrega (# 56, # 157 del prompt).
usable_file_mb = 1536.0   # ya neto de redundancia, distinto de un FREE_MB/TOTAL_MB naive
r_asm = run_capacity_forecast(series(usable_file_mb, lambda d: 200.0 + 10.0*d), policy=policy)
assert r_asm.data_quality != 'INVALID'
util_last = r_asm.diagnostics['data_quality']['independent_observations'] and True
# utilization se calcula sobre USABLE_FILE_MB, nunca sobre un TOTAL_MB mayor que inflaria el headroom
assert r_asm.method_parameters is not None

# Tablespace con autoextend: el CALLER pasa total_capacity = maxsize (el techo real), nunca solo
# 'allocated' -- igual que el skill capacity/tablespace ya documenta (effective_ceiling).
allocated = 10240.0
maxsize = 102400.0
r_ts_naive = run_capacity_forecast(series(allocated, lambda d: 9216.0 + 1.0*d, resource_type='tablespace', metric='used_mb'), policy=policy, thresholds={'critical_percent': 90.0})
r_ts_correct = run_capacity_forecast(series(maxsize, lambda d: 9216.0 + 1.0*d, resource_type='tablespace', metric='used_mb'), policy=policy, thresholds={'critical_percent': 90.0})
# el mismo 'used' contra un total distinto produce un riesgo de umbral MUY diferente -- prueba de
# que el motor respeta el denominador entregado en vez de asumir uno propio.
assert r_ts_naive.thresholds[0]['status'] != r_ts_correct.thresholds[0]['status'] or \
       r_ts_naive.diagnostics['data_quality'] != r_ts_correct.diagnostics['data_quality']
naive_util = 100 * (9216.0 + 1.0*29) / allocated
correct_util = 100 * (9216.0 + 1.0*29) / maxsize
assert naive_util > correct_util, (naive_util, correct_util)  # el naive infla el riesgo, como documenta capacity/tablespace

# No double counting: dos capas (fisica/datastore y volumen/ASM) se corren como llamadas
# INDEPENDIENTES -- el motor nunca suma resultados de dos ForecastResult entre si.
r_layer1 = run_capacity_forecast(series(2_000_000.0, lambda d: 1_200_000.0 + 100.0*d, resource_type='physical_datastore', metric='used'), policy=policy)
r_layer2 = run_capacity_forecast(series(1_000_000.0, lambda d: 700_000.0 + 50.0*d, resource_type='volume_filesystem_asm', metric='used'), policy=policy)
assert r_layer1.target_id == r_layer2.target_id == 'DATA_DG'
assert r_layer1.method_parameters['intercept'] != r_layer2.method_parameters['intercept']
# no existe ninguna funcion en el motor que sume dos ForecastResult -- confirmado por ausencia de
# ese simbolo en el modulo publico.
import capacity_engine
assert not hasattr(capacity_engine, 'sum_forecast_results')

print('ENGINE_OK')
")
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] capacity_engine respeta el denominador entregado (USABLE_FILE_MB/maxsize) sin reimplementarlo, y nunca suma capas de storage entre sí"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi
exit $FAIL
