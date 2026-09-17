#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 71 (# 1575-1585 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/normalization/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'capacity_metric:' "$S" && echo "[PASS] declara el Common Metric Model capacity_metric" || { echo "[FAIL] falta capacity_metric:"; FAIL=1; }
grep -q 'utilization_percent: number|null' "$S" && echo "[PASS] declara utilization_percent en el esquema" || { echo "[FAIL] falta utilization_percent"; FAIL=1; }
grep -q 'total_capacity: number|null' "$S" && echo "[PASS] declara total_capacity en el esquema" || { echo "[FAIL] falta total_capacity"; FAIL=1; }
exit $FAIL
