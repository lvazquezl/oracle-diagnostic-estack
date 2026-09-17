#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 77/32.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
T="$ROOT/skills/capacity/trend-analysis/SKILL.md"
FX="$ROOT/tests/fixtures/capacity-flat-trend-cpu.yaml"

[ -f "$T" ] || { echo "[FAIL] falta $T"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta fixture $FX"; exit 1; }
grep -q 'STABLE' "$T" && echo "[PASS] trend-analysis clasifica STABLE" || { echo "[FAIL] falta la clasificación STABLE"; FAIL=1; }
grep -q 'trend_classification: STABLE' "$FX" && echo "[PASS] fixture de tendencia plana presente" || { echo "[FAIL] fixture no declara STABLE"; FAIL=1; }
exit $FAIL
