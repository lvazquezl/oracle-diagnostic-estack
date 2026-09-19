#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: CONFIRMED_ROOT_CAUSE requiere 2 fuentes de
# evidencia independientes o prueba temporal inequívoca — nunca proximidad temporal sola.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
DOC="$ROOT/docs/INCIDENT_ROOT_CAUSE_MODEL.md"
MANIFEST="$ROOT/agents/incident-root-cause-analyst/manifest.yaml"

grep -qi 'dos fuentes de evidencia independientes' "$DOC" \
  && echo "[PASS] regla de 2 fuentes independientes declarada" \
  || { echo "[FAIL] falta la regla de 2 fuentes independientes"; FAIL=1; }

grep -qi 'prueba temporal inequívoca' "$DOC" \
  && echo "[PASS] regla de prueba temporal inequívoca declarada" \
  || { echo "[FAIL] falta la regla de prueba temporal inequívoca"; FAIL=1; }

grep -qi 'CONFIRMED_ROOT_CAUSE sin al menos dos fuentes' "$MANIFEST" \
  && echo "[PASS] manifest.yaml never_reports prohíbe CONFIRMED_ROOT_CAUSE sin evidencia suficiente" \
  || { echo "[FAIL] falta la regla en output_contract.never_reports del manifest"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] No hay confirmación falsa de root cause posible por diseño"
exit $FAIL
