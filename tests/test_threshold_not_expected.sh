#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 78/44 (# 1018-1035 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/threshold-crossing/SKILL.md"
FX="$ROOT/tests/fixtures/capacity-flat-trend-cpu.yaml"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta fixture $FX"; exit 1; }
grep -q 'NOT_EXPECTED_WITHIN_HORIZON' "$S" && echo "[PASS] declara el estado NOT_EXPECTED_WITHIN_HORIZON" || { echo "[FAIL] falta NOT_EXPECTED_WITHIN_HORIZON"; FAIL=1; }
grep -q 'threshold_crossing_status: NOT_EXPECTED_WITHIN_HORIZON' "$FX" && echo "[PASS] fixture de tendencia plana espera NOT_EXPECTED_WITHIN_HORIZON" || { echo "[FAIL] fixture no declara NOT_EXPECTED_WITHIN_HORIZON"; FAIL=1; }
exit $FAIL
