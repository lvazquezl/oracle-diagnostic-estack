#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: incident/hypothesis-testing declara el
# ranking basado en múltiples factores (evidencia, consistencia temporal, plausibilidad
# mecanística), no sólo el orden de generación.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/incident/hypothesis-testing/SKILL.md"
DOC="$ROOT/docs/INCIDENT_HYPOTHESIS_MODEL.md"

grep -q '## Ranking' "$SKILL" \
  && echo "[PASS] incident/hypothesis-testing declara la sección Ranking" \
  || { echo "[FAIL] falta la sección Ranking en incident/hypothesis-testing/SKILL.md"; FAIL=1; }

for status in OPEN SUPPORTED WEAKENED REJECTED CONFIRMED INSUFFICIENT_EVIDENCE; do
  grep -q "$status" "$DOC" || { echo "[FAIL] falta el estado $status en docs/INCIDENT_HYPOTHESIS_MODEL.md"; FAIL=1; }
done

[ $FAIL -eq 0 ] && echo "[PASS] Modelo de soporte/ranking de hipótesis completo"
exit $FAIL
