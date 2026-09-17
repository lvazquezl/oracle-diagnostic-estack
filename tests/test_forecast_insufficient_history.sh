#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 77/25 (# 671-692, # 54 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/forecasting/SKILL.md"
FX="$ROOT/tests/fixtures/capacity-insufficient-history-memory.yaml"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta fixture $FX"; exit 1; }
grep -q 'confidence: INSUFFICIENT' "$S" && echo "[PASS] declara confidence: INSUFFICIENT sin historia suficiente" || { echo "[FAIL] falta confidence: INSUFFICIENT"; FAIL=1; }
grep -q 'forecast_produced: false' "$FX" && echo "[PASS] fixture confirma que no se produce forecast sin historia suficiente" || { echo "[FAIL] fixture no confirma forecast_produced: false"; FAIL=1; }
exit $FAIL
