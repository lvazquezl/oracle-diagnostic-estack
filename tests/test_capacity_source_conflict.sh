#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 79/53 (# 1190-1206 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/capacity-assessment/SKILL.md"
FX="$ROOT/tests/fixtures/capacity-source-conflict-cpu.yaml"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta fixture $FX"; exit 1; }
grep -q 'SOURCE_CONFLICT' "$S" && echo "[PASS] declara el estado SOURCE_CONFLICT" || { echo "[FAIL] falta SOURCE_CONFLICT"; FAIL=1; }
grep -q 'status: SOURCE_CONFLICT' "$FX" && echo "[PASS] fixture de conflicto de fuentes presente" || { echo "[FAIL] fixture no declara SOURCE_CONFLICT"; FAIL=1; }
exit $FAIL
