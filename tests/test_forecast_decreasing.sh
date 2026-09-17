#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 77/32.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
T="$ROOT/skills/capacity/trend-analysis/SKILL.md"
FX="$ROOT/tests/fixtures/capacity-decreasing-trend-memory.yaml"

[ -f "$T" ] || { echo "[FAIL] falta $T"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta fixture $FX"; exit 1; }
grep -q 'DECREASING' "$T" && echo "[PASS] trend-analysis clasifica DECREASING" || { echo "[FAIL] falta la clasificación DECREASING"; FAIL=1; }
grep -q 'trend_classification: DECREASING' "$FX" && echo "[PASS] fixture de tendencia decreciente presente" || { echo "[FAIL] fixture no declara DECREASING"; FAIL=1; }
exit $FAIL
