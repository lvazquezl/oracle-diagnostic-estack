#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 83/68 (# 1527-1539 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/forecasting/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'excluded_samples: \[string\]' "$S" && echo "[PASS] el forecast registra excluded_samples" || { echo "[FAIL] falta excluded_samples"; FAIL=1; }
grep -q 'registrar la regla de exclusión' "$S" && echo "[PASS] declara que la regla de exclusión se registra explícitamente" || { echo "[FAIL] falta la disciplina de registro de exclusión"; FAIL=1; }
exit $FAIL
