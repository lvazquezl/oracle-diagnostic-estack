#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: incident/rca-report distingue
# CHANGE_CORRELATED de CHANGE_CAUSED en el reporte y nunca infla la confianza final.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/incident/rca-report/SKILL.md"

grep -q 'CHANGE_CORRELATED' "$SKILL" && grep -q 'CHANGE_CAUSED' "$SKILL" \
  && echo "[PASS] incident/rca-report distingue CHANGE_CORRELATED de CHANGE_CAUSED" \
  || { echo "[FAIL] falta la distinción CHANGE_CORRELATED/CHANGE_CAUSED en rca-report"; FAIL=1; }

grep -qi 'nunca inflado' "$SKILL" \
  && echo "[PASS] incident/rca-report declara que nunca infla la confianza" \
  || { echo "[FAIL] falta la declaración de no inflar confianza"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] incident/rca-report consistente"
exit $FAIL
