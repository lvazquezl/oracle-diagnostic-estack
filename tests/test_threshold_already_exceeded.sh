#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 78/44 (# 1018-1035 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/threshold-crossing/SKILL.md"
FX="$ROOT/tests/fixtures/capacity-threshold-already-exceeded.yaml"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta fixture $FX"; exit 1; }
grep -q 'ALREADY_EXCEEDED' "$S" && echo "[PASS] declara el estado ALREADY_EXCEEDED" || { echo "[FAIL] falta ALREADY_EXCEEDED"; FAIL=1; }
grep -q 'threshold_crossing_status: ALREADY_EXCEEDED' "$FX" && echo "[PASS] fixture de umbral ya excedido presente" || { echo "[FAIL] fixture no declara ALREADY_EXCEEDED"; FAIL=1; }
exit $FAIL
