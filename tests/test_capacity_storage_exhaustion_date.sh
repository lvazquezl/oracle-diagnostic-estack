#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 75/45 (# 1038-1056 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
T="$ROOT/skills/capacity/threshold-crossing/SKILL.md"

[ -f "$T" ] || { echo "[FAIL] falta $T"; exit 1; }
grep -q 'saturation_date' "$T" && echo "[PASS] declara saturation_date para recursos acumulativos" || { echo "[FAIL] falta saturation_date"; FAIL=1; }
grep -q 'nunca CPU' "$T" && echo "[PASS] saturation_date excluye explícitamente CPU" || { echo "[FAIL] falta la exclusión explícita de CPU"; FAIL=1; }
exit $FAIL
