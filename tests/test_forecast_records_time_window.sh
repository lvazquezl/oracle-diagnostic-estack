#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 83/68 (# 1527-1539 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/forecasting/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'time_window:' "$S" && echo "[PASS] el forecast registra time_window" || { echo "[FAIL] falta time_window"; FAIL=1; }
grep -q 'aggregation: hourly|daily|weekly|monthly' "$S" && echo "[PASS] time_window incluye la agregación usada" || { echo "[FAIL] falta la agregación en time_window"; FAIL=1; }
exit $FAIL
