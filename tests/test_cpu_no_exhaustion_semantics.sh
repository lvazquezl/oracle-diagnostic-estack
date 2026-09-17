#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 46 (# 1059-1074 del prompt):
# CPU es utilización, nunca "days until CPU exhausted".
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
C="$ROOT/skills/capacity/cpu/SKILL.md"
T="$ROOT/skills/capacity/threshold-crossing/SKILL.md"

[ -f "$C" ] || { echo "[FAIL] falta $C"; exit 1; }
[ -f "$T" ] || { echo "[FAIL] falta $T"; exit 1; }
grep -q 'días hasta agotar CPU' "$C" && echo "[PASS] capacity/cpu declara la disciplina anti-exhaustion-semantics" || { echo "[FAIL] falta la disciplina en capacity/cpu"; FAIL=1; }
grep -q 'días hasta agotar' "$T" && echo "[PASS] threshold-crossing declara nunca usar días-hasta-agotar para CPU" || { echo "[FAIL] falta la disciplina en threshold-crossing"; FAIL=1; }
grep -q 'sustained utilization risk' "$T" && echo "[PASS] threshold-crossing prefiere sustained utilization risk" || { echo "[FAIL] falta sustained utilization risk"; FAIL=1; }
grep -q 'nunca aplicado automáticamente a CPU' "$T" && echo "[PASS] saturation_date nunca aplicado automáticamente a CPU" || { echo "[FAIL] falta la exclusión de CPU de saturation_date"; FAIL=1; }
exit $FAIL
