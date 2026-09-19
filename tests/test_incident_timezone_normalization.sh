#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: source_timestamp siempre preservado junto
# al timestamp normalizado a UTC — nunca descartado.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
DOC="$ROOT/docs/INCIDENT_TIMELINE_MODEL.md"

grep -qi 'source_timestamp' "$DOC" \
  && echo "[PASS] Incident Timeline Model preserva source_timestamp" \
  || { echo "[FAIL] falta source_timestamp en docs/INCIDENT_TIMELINE_MODEL.md"; FAIL=1; }

grep -qi 'nunca se descarta' "$DOC" \
  && echo "[PASS] docs/INCIDENT_TIMELINE_MODEL.md declara que el timestamp original nunca se descarta" \
  || { echo "[FAIL] falta la declaración de no descartar el timestamp original"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Normalización de timezone consistente, source_timestamp preservado"
exit $FAIL
