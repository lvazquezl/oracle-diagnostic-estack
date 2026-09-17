#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 73/46 (# 1059-1074 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/cpu/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'cpu-forecast-semantics' "$S" && echo "[PASS] referencia el modelo de forecast CPU (threshold-crossing#cpu-forecast-semantics)" || { echo "[FAIL] falta la referencia a cpu-forecast-semantics"; FAIL=1; }
exit $FAIL
