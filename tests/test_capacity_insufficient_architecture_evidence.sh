#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 80/24 (# 644-667 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
H="$ROOT/skills/capacity/horizontal/SKILL.md"
V="$ROOT/skills/capacity/vertical/SKILL.md"
FX="$ROOT/tests/fixtures/capacity-horizontal-vertical-insufficient-evidence.yaml"

[ -f "$H" ] || { echo "[FAIL] falta $H"; exit 1; }
[ -f "$V" ] || { echo "[FAIL] falta $V"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta fixture $FX"; exit 1; }
grep -q 'INSUFFICIENT_EVIDENCE' "$H" && echo "[PASS] capacity/horizontal declara INSUFFICIENT_EVIDENCE" || { echo "[FAIL] falta INSUFFICIENT_EVIDENCE en horizontal"; FAIL=1; }
grep -q 'INSUFFICIENT_EVIDENCE' "$V" && echo "[PASS] capacity/vertical declara INSUFFICIENT_EVIDENCE" || { echo "[FAIL] falta INSUFFICIENT_EVIDENCE en vertical"; FAIL=1; }
grep -q 'forced_recommendation_by_percent_alone: false' "$FX" && echo "[PASS] fixture confirma que nunca se fuerza recomendación sólo por porcentaje" || { echo "[FAIL] fixture no confirma la ausencia de recomendación forzada"; FAIL=1; }
exit $FAIL
