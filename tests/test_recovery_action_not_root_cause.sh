#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: una acción de recuperación exitosa no
# prueba por sí misma la causa raíz — ejemplo "restart listener restored service".
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/incident/recovery-status/SKILL.md"
DOC="$ROOT/docs/INCIDENT_CAUSALITY_MODEL.md"

grep -q '## Recovery action' "$SKILL" \
  && echo "[PASS] incident/recovery-status declara la sección Recovery action" \
  || { echo "[FAIL] falta la sección de recovery action en incident/recovery-status"; FAIL=1; }

grep -qi 'restart listener restored service' "$SKILL" \
  && echo "[PASS] ejemplo verbatim del prompt presente" \
  || { echo "[FAIL] falta el ejemplo verbatim del prompt"; FAIL=1; }

grep -qi 'recovery action' "$DOC" \
  && echo "[PASS] docs/INCIDENT_CAUSALITY_MODEL.md declara la regla recovery action ≠ root cause" \
  || { echo "[FAIL] falta la regla en docs/INCIDENT_CAUSALITY_MODEL.md"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Acción de recuperación nunca tratada como prueba de root cause"
exit $FAIL
