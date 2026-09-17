#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 75/48 (# 1092-1106 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/storage/SKILL.md"
FX="$ROOT/tests/fixtures/capacity-linear-growth-storage.yaml"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta fixture $FX"; exit 1; }
grep -q 'priorizar growth rate' "$S" && echo "[PASS] prioriza growth rate para storage acumulativo" || { echo "[FAIL] falta priorizar growth rate"; FAIL=1; }
grep -q 'INCREASING' "$FX" && echo "[PASS] fixture de crecimiento lineal presente" || { echo "[FAIL] fixture no declara INCREASING"; FAIL=1; }
exit $FAIL
