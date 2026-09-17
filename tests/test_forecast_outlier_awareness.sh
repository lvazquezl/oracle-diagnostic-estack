#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 77/37 (# 881-897 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/forecasting/SKILL.md"
FX="$ROOT/tests/fixtures/capacity-outliers-storage.yaml"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta fixture $FX"; exit 1; }
grep -q 'nunca eliminarlos silenciosamente' "$S" && echo "[PASS] declara detect/flag/compare, nunca eliminación silenciosa" || { echo "[FAIL] falta la disciplina anti-eliminación-silenciosa"; FAIL=1; }
grep -q 'outlier_silently_removed: false' "$FX" && echo "[PASS] fixture confirma que el outlier nunca se elimina silenciosamente" || { echo "[FAIL] fixture no confirma outlier_silently_removed: false"; FAIL=1; }
exit $FAIL
