#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: CORRELATION IS NOT CAUSATION — proximidad
# temporal sola nunca es prueba suficiente de causalidad.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
DOC="$ROOT/docs/INCIDENT_CAUSALITY_MODEL.md"

grep -q 'CORRELATION IS NOT CAUSATION' "$DOC" \
  && echo "[PASS] principio CORRELATION IS NOT CAUSATION declarado" \
  || { echo "[FAIL] falta el principio CORRELATION IS NOT CAUSATION"; FAIL=1; }

tr '\n' ' ' < "$DOC" | grep -qi 'proximidad temporal sola nunca es prueba suficiente' \
  && echo "[PASS] regla de proximidad temporal insuficiente declarada" \
  || { echo "[FAIL] falta la regla de proximidad temporal insuficiente"; FAIL=1; }

grep -qi 'CORRELATION IS NOT CAUSATION\|correlación.*no.*causación\|correlation.*not.*causation' \
  "$ROOT/agents/incident-root-cause-analyst/manifest.yaml" \
  || grep -qi 'proximidad temporal' "$ROOT/agents/incident-root-cause-analyst/manifest.yaml" \
  && echo "[PASS] agente declara la regla de correlación no es causación" \
  || { echo "[FAIL] falta la regla en el manifest del agente"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Correlación temporal nunca tratada como causación"
exit $FAIL
