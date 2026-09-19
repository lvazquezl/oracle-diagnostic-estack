#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: incident/blast-radius declara los 11
# niveles de clasificación y UNKNOWN como resultado correcto sin evidencia suficiente.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/incident/blast-radius/SKILL.md"

for level in INSTANCE DATABASE PDB RAC_NODE RAC_CLUSTER HOST SERVICE DATAGUARD_CONFIG STORAGE NETWORK_SEGMENT MULTIPLE_SYSTEMS UNKNOWN; do
  grep -q "$level" "$SKILL" || { echo "[FAIL] falta el nivel $level en incident/blast-radius/SKILL.md"; FAIL=1; }
done

grep -qi 'nunca sobreestima' "$SKILL" \
  && echo "[PASS] incident/blast-radius declara que nunca sobreestima el alcance" \
  || { echo "[FAIL] falta la declaración de no sobreestimar"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] incident/blast-radius con los 11 niveles y sin sobreestimación"
exit $FAIL
