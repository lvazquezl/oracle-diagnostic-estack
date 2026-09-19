#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: identificador INC-YYYYMMDD-NNN consistente
# con el resto de la cadena de identificadores (EVD-/FND-/HYP-/RCA-/REC-/CHG-).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

grep -q 'INC-YYYYMMDD-NNN' "$ROOT/docs/INCIDENT_INTAKE_MODEL.md" \
  && echo "[PASS] Incident Intake Model declara el identificador INC-YYYYMMDD-NNN" \
  || { echo "[FAIL] falta el identificador INC-YYYYMMDD-NNN"; FAIL=1; }

grep -q 'INC-YYYYMMDD-NNN.*EVD-.*FND-.*HYP-.*RCA-.*REC-.*CHG-' "$ROOT/docs/INCIDENT_EVIDENCE_MODEL.md" \
  && echo "[PASS] Incident Evidence Model declara la cadena completa de identificadores" \
  || { echo "[FAIL] falta la cadena completa de identificadores en docs/INCIDENT_EVIDENCE_MODEL.md"; FAIL=1; }

grep -q 'INC-YYYYMMDD-NNN' "$ROOT/workflows/incident.md" \
  && echo "[PASS] workflows/incident.md referencia INC-YYYYMMDD-NNN" \
  || { echo "[FAIL] falta la referencia a INC-YYYYMMDD-NNN en workflows/incident.md"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Identificador de incidente consistente en todo el dominio"
exit $FAIL
