#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 77/39 (# 924-935 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/forecasting/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'horizon_6m:' "$S" && echo "[PASS] declara horizon_6m" || { echo "[FAIL] falta horizon_6m"; FAIL=1; }
grep -q 'partiendo siempre del último dato' "$S" && echo "[PASS] los horizontes parten siempre del último dato válido" || { echo "[FAIL] falta la disciplina del último dato válido"; FAIL=1; }
exit $FAIL
