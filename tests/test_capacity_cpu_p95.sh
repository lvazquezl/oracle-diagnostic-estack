#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 73/11 (# 410-424 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/cpu/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'p95 CPU' "$S" && echo "[PASS] soporta p95 CPU" || { echo "[FAIL] falta p95 CPU"; FAIL=1; }
grep -q 'único pico puntual como baseline' "$S" && echo "[PASS] nunca usa un único pico puntual como baseline" || { echo "[FAIL] falta la disciplina anti-pico-puntual"; FAIL=1; }
exit $FAIL
