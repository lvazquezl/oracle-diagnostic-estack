#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: toda evidencia de incidente es referenciada
# por evidence_ids trazables (EVD-*), nunca duplicada cruda en el reporte.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
DOC="$ROOT/docs/INCIDENT_EVIDENCE_MODEL.md"

grep -q 'INC-YYYYMMDD-NNN' "$DOC" && grep -q 'EVD-' "$DOC" \
  && echo "[PASS] docs/INCIDENT_EVIDENCE_MODEL.md declara la cadena de identificadores de evidencia" \
  || { echo "[FAIL] falta la cadena de identificadores de evidencia"; FAIL=1; }

grep -qi 'evidencia por referencia' "$DOC" \
  && echo "[PASS] evidencia por referencia declarada" \
  || { echo "[FAIL] falta la declaración de evidencia por referencia"; FAIL=1; }

grep -qi 'evidence_ids' "$ROOT/skills/incident/root-cause/SKILL.md" \
  || { echo "[FAIL] falta evidence_ids en incident/root-cause/SKILL.md"; FAIL=1; }
grep -qi 'evidencia' "$ROOT/skills/incident/rca-report/SKILL.md" \
  || { echo "[FAIL] falta referencia a evidencia en incident/rca-report/SKILL.md"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Trazabilidad de evidencia consistente en todo el dominio"
exit $FAIL
