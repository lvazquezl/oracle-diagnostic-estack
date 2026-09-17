#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 76/17 (# 523-536 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/tablespace/SKILL.md"
FX="$ROOT/tests/fixtures/capacity-tablespace-autoextend.yaml"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta fixture $FX"; exit 1; }
grep -q 'effective_ceiling' "$S" && echo "[PASS] distingue el techo real (effective_ceiling)" || { echo "[FAIL] falta effective_ceiling"; FAIL=1; }
grep -q 'maxsize - used' "$S" && echo "[PASS] usa maxsize - used cuando autoextend habilitado" || { echo "[FAIL] falta la fórmula maxsize - used"; FAIL=1; }
grep -q 'effective_ceiling_source: maxsize' "$FX" && echo "[PASS] fixture espera el techo maxsize" || { echo "[FAIL] fixture no espera maxsize como techo"; FAIL=1; }
exit $FAIL
