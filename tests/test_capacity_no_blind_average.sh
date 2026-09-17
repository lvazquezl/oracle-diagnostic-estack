#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 79/52 (# 1167-1206 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/capacity-assessment/SKILL.md"
FX="$ROOT/tests/fixtures/capacity-source-conflict-cpu.yaml"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta fixture $FX"; exit 1; }
grep -q 'promediado a ciegas' "$S" && echo "[PASS] declara que un conflicto nunca se promedia a ciegas" || { echo "[FAIL] falta la disciplina anti-blind-average"; FAIL=1; }
grep -q 'blind_average_used: false' "$FX" && echo "[PASS] fixture confirma que no se usa promedio a ciegas" || { echo "[FAIL] fixture no confirma blind_average_used: false"; FAIL=1; }
exit $FAIL
