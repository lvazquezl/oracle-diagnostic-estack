#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: hipótesis REJECTED/WEAKENED son
# resultados legítimos, nunca ocultados del reporte final — incident/rca-report las lista siempre.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
DOC="$ROOT/docs/INCIDENT_HYPOTHESIS_MODEL.md"
RCA_SKILL="$ROOT/skills/incident/rca-report/SKILL.md"

tr '\n' ' ' < "$DOC" | grep -qi 'nunca[^.]*ocultados del reporte final' \
  && echo "[PASS] REJECTED/WEAKENED nunca se ocultan del reporte final" \
  || { echo "[FAIL] falta la declaración de no ocultar hipótesis rechazadas"; FAIL=1; }

grep -qi 'omite las hipótesis rechazadas' "$RCA_SKILL" \
  && echo "[PASS] incident/rca-report declara que nunca omite las hipótesis rechazadas" \
  || { echo "[FAIL] falta la declaración de no omitir hipótesis rechazadas en incident/rca-report"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Rechazo de hipótesis tratado como resultado legítimo y trazable"
exit $FAIL
