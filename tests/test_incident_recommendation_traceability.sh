#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: toda recomendación de remediación
# (REC-*/CHG-*) se vincula explícitamente a la causa/hipótesis que atiende — nunca huérfana.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
DOC="$ROOT/docs/INCIDENT_MANUAL_REMEDIATION_MODEL.md"

grep -q 'REC-' "$ROOT/docs/INCIDENT_EVIDENCE_MODEL.md" && grep -q 'CHG-' "$ROOT/docs/INCIDENT_EVIDENCE_MODEL.md" \
  && echo "[PASS] REC-/CHG- presentes en la cadena de identificadores" \
  || { echo "[FAIL] falta REC-/CHG- en la cadena de identificadores"; FAIL=1; }

grep -qi 'nunca una acción' "$DOC" \
  && echo "[PASS] docs/INCIDENT_MANUAL_REMEDIATION_MODEL.md prohíbe acciones huérfanas" \
  || { echo "[FAIL] falta la prohibición de acciones huérfanas"; FAIL=1; }

grep -q 'linked_to: RCA-...|HYP-...' "$ROOT/skills/incident/manual-remediation-plan/SKILL.md" \
  && echo "[PASS] manual-remediation-plan declara linked_to en el output schema" \
  || { echo "[FAIL] falta linked_to en el output schema de manual-remediation-plan"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Trazabilidad de recomendaciones consistente"
exit $FAIL
