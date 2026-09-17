#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 76/18 (# 539-554 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/oracle/SKILL.md"
FX="$ROOT/tests/fixtures/capacity-fra-pressure.yaml"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta fixture $FX"; exit 1; }
grep -q 'space_reclaimable' "$S" && echo "[PASS] declara space_reclaimable en el bloque FRA" || { echo "[FAIL] falta space_reclaimable"; FAIL=1; }
grep -q 'integrado con Fase 7' "$S" && echo "[PASS] declara integración con Fase 7 (RMAN/FRA)" || { echo "[FAIL] falta la referencia a Fase 7"; FAIL=1; }
grep -q 'auto_reclaim_executed: false' "$FX" && echo "[PASS] fixture confirma que nunca se hace reclaim automático" || { echo "[FAIL] fixture no confirma auto_reclaim_executed: false"; FAIL=1; }
exit $FAIL
