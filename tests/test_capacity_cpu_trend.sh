#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 73/32.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/cpu/SKILL.md"
T="$ROOT/skills/capacity/trend-analysis/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$T" ] || { echo "[FAIL] falta $T"; exit 1; }
grep -q 'capacity/trend-analysis' "$S" && echo "[PASS] capacity/cpu alimenta capacity/trend-analysis" || { echo "[FAIL] falta la referencia a trend-analysis"; FAIL=1; }
grep -q 'INCREASING' "$T" && echo "[PASS] trend-analysis clasifica INCREASING/DECREASING/STABLE/VOLATILE" || { echo "[FAIL] falta la clasificación de tendencia"; FAIL=1; }
exit $FAIL
