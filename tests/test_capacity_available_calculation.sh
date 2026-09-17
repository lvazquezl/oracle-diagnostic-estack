#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 71/10 (# 383-387 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/normalization/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'available_capacity = total_capacity - used_capacity' "$S" && echo "[PASS] declara la ecuación base available = total - used" || { echo "[FAIL] falta la ecuación available_capacity"; FAIL=1; }
grep -q 'utilization_percent = used_capacity / total_capacity \* 100' "$S" && echo "[PASS] declara la ecuación utilization_percent" || { echo "[FAIL] falta la ecuación utilization_percent"; FAIL=1; }
exit $FAIL
