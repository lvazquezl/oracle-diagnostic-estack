#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 74/32.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/memory/SKILL.md"
FX="$ROOT/tests/fixtures/capacity-decreasing-trend-memory.yaml"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta fixture $FX"; exit 1; }
grep -q 'capacity/trend-analysis' "$S" && echo "[PASS] capacity/memory alimenta capacity/trend-analysis" || { echo "[FAIL] falta la referencia a trend-analysis"; FAIL=1; }
grep -q 'DECREASING' "$FX" && echo "[PASS] fixture de tendencia decreciente presente" || { echo "[FAIL] fixture no declara DECREASING"; FAIL=1; }
exit $FAIL
