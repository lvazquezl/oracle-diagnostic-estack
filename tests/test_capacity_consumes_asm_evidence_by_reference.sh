#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 82/16 (# 501-519 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/asm/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'Reutiliza por referencia' "$S" && echo "[PASS] capacity/asm reutiliza por referencia asm/capacity (Fase 4)" || { echo "[FAIL] falta la reutilización por referencia"; FAIL=1; }
grep -q 'nunca duplica el collector' "$S" && echo "[PASS] capacity/asm declara que nunca duplica el collector" || { echo "[FAIL] falta la disciplina anti-duplicación"; FAIL=1; }
exit $FAIL
