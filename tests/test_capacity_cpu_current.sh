#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 73/11 (# 410-425 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/cpu/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'cpu_capacity:' "$S" && echo "[PASS] declara el esquema cpu_capacity" || { echo "[FAIL] falta cpu_capacity:"; FAIL=1; }
grep -q 'allocated: number|null' "$S" && echo "[PASS] declara allocated CPU" || { echo "[FAIL] falta allocated"; FAIL=1; }
grep -q 'used: number|null' "$S" && echo "[PASS] declara used CPU" || { echo "[FAIL] falta used"; FAIL=1; }
exit $FAIL
