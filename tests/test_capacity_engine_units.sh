#!/usr/bin/env bash
# PHASE 10 — FORECASTING EXECUTION & NUMERICAL VALIDATION HARDENING, sección 10/caso 11
# (# 154 del prompt): GB vs GiB, bytes, total cero, NaN, infinito, used negativo e
# incompatibilidad CPU cores/%.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys, math; sys.path.insert(0, '.')
from capacity_engine.normalization import normalize_samples
from capacity_engine.common import ValidationErrorType

base = {'target_id': 'T-UNIT', 'technology': 'linux', 'resource_type': 'filesystem',
        'metric_name': 'used', 'source_id': 'fx', 'evidence_id': 'EVD-1'}

# GB decimal vs GiB binario -- deben convertirse a bytes canonicos con factores DISTINTOS.
gb = dict(base, timestamp='2026-01-01T00:00:00+00:00', total_capacity=1.0, used_capacity=0.5, unit='GB')
gib = dict(base, timestamp='2026-01-02T00:00:00+00:00', total_capacity=1.0, used_capacity=0.5, unit='GiB')
n1 = normalize_samples([gb])['samples'][0]
n2 = normalize_samples([gib])['samples'][0]
assert n1.total_capacity == 1_000_000_000.0, n1.total_capacity
assert n2.total_capacity == 1024**3, n2.total_capacity
assert n1.total_capacity != n2.total_capacity

# bytes ya canonico -- factor 1, sin conversion.
b = dict(base, timestamp='2026-01-03T00:00:00+00:00', total_capacity=500.0, used_capacity=100.0, unit='bytes')
n3 = normalize_samples([b])['samples'][0]
assert n3.total_capacity == 500.0

# total cero -> excluido, INVALID_CAPACITY_INPUT.
zero = dict(base, timestamp='2026-01-04T00:00:00+00:00', total_capacity=0.0, used_capacity=1.0, unit='bytes')
r_zero = normalize_samples([zero])
assert len(r_zero['samples']) == 0
assert r_zero['issues'][0].error_type == ValidationErrorType.INVALID_CAPACITY_INPUT.value

# NaN / infinito -> excluidos, nunca propagados.
nan_s = dict(base, timestamp='2026-01-05T00:00:00+00:00', total_capacity=float('nan'), used_capacity=1.0, unit='bytes')
inf_s = dict(base, timestamp='2026-01-06T00:00:00+00:00', total_capacity=float('inf'), used_capacity=1.0, unit='bytes')
r_nan = normalize_samples([nan_s]); r_inf = normalize_samples([inf_s])
assert len(r_nan['samples']) == 0
assert len(r_inf['samples']) == 0

# used negativo -> excluido.
neg = dict(base, timestamp='2026-01-07T00:00:00+00:00', total_capacity=100.0, used_capacity=-5.0, unit='bytes')
r_neg = normalize_samples([neg])
assert len(r_neg['samples']) == 0
assert r_neg['issues'][0].error_type == ValidationErrorType.NEGATIVE_USED.value

# CPU cores vs percentage -- unidades incompatibles dentro de la MISMA serie, la segunda excluida.
cpu1 = dict(base, resource_type='cpu', timestamp='2026-01-08T00:00:00+00:00', total_capacity=16.0, used_capacity=4.0, unit='cores')
cpu2 = dict(base, resource_type='cpu', timestamp='2026-01-09T00:00:00+00:00', total_capacity=100.0, used_capacity=50.0, unit='percentage')
r_cpu = normalize_samples([cpu1, cpu2])
assert len(r_cpu['samples']) == 1, r_cpu
assert r_cpu['issues'][0].error_type == ValidationErrorType.UNIT_MISMATCH.value

print('ENGINE_OK')
")
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] capacity_engine.normalization distingue GB decimal/GiB binario, rechaza total<=0/NaN/inf/used negativo y detecta mezcla cores/percentage en CPU"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi
exit $FAIL
