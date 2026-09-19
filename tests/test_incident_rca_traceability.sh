#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: incident/rca-report reconstruye el
# razonamiento completo (RCA-*) — reproducible por otro analista con la misma evidencia.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/incident/rca-report/SKILL.md"

grep -qi 'RCA MUST BE REPRODUCIBLE' "$SKILL" \
  && echo "[PASS] incident/rca-report declara RCA MUST BE REPRODUCIBLE" \
  || { echo "[FAIL] falta la declaración RCA MUST BE REPRODUCIBLE"; FAIL=1; }

grep -q 'RCA-' "$ROOT/docs/INCIDENT_EVIDENCE_MODEL.md" \
  && echo "[PASS] RCA- presente en la cadena de identificadores" \
  || { echo "[FAIL] falta RCA- en la cadena de identificadores"; FAIL=1; }

grep -qi 'reproducible por otro DBA' "$SKILL" \
  && echo "[PASS] incident/rca-report declara reproducibilidad por otro DBA" \
  || { echo "[FAIL] falta la declaración de reproducibilidad"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Trazabilidad de RCA consistente y reproducible"
exit $FAIL
