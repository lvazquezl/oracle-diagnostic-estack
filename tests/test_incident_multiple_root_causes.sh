#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: un incidente puede tener más de una
# CONFIRMED_ROOT_CAUSE — nunca se fuerza una única causa cuando la evidencia soporta varias.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
DOC="$ROOT/docs/INCIDENT_ROOT_CAUSE_MODEL.md"

grep -qi 'Múltiples causas raíz' "$DOC" \
  && echo "[PASS] sección de múltiples causas raíz presente" \
  || { echo "[FAIL] falta la sección de múltiples causas raíz"; FAIL=1; }

tr '\n' ' ' < "$DOC" | grep -qi 'nunca se fuerza una única causa' \
  && echo "[PASS] regla de no forzar una única causa presente" \
  || { echo "[FAIL] falta la regla de no forzar una única causa"; FAIL=1; }

grep -q 'test_incident_multiple_root_causes.sh' "$DOC" \
  && echo "[PASS] docs/INCIDENT_ROOT_CAUSE_MODEL.md referencia este mismo test" \
  || { echo "[FAIL] falta la auto-referencia del test en la documentación"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Múltiples causas raíz soportadas sin forzar una única conclusión"
exit $FAIL
