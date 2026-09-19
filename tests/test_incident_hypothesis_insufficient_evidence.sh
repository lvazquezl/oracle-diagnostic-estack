#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: INSUFFICIENT_EVIDENCE es un estado
# legítimo tanto a nivel de hipótesis como de root cause (UNDETERMINED) — nunca forzado.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

grep -q 'INSUFFICIENT_EVIDENCE' "$ROOT/docs/INCIDENT_HYPOTHESIS_MODEL.md" \
  && echo "[PASS] docs/INCIDENT_HYPOTHESIS_MODEL.md declara INSUFFICIENT_EVIDENCE" \
  || { echo "[FAIL] falta INSUFFICIENT_EVIDENCE en docs/INCIDENT_HYPOTHESIS_MODEL.md"; FAIL=1; }

grep -q 'INSUFFICIENT_EVIDENCE' "$ROOT/docs/INCIDENT_ROOT_CAUSE_MODEL.md" \
  && echo "[PASS] docs/INCIDENT_ROOT_CAUSE_MODEL.md declara completeness INSUFFICIENT_EVIDENCE" \
  || { echo "[FAIL] falta INSUFFICIENT_EVIDENCE en docs/INCIDENT_ROOT_CAUSE_MODEL.md"; FAIL=1; }

grep -qi 'UNDETERMINED' "$ROOT/docs/INCIDENT_ROOT_CAUSE_MODEL.md" \
  && echo "[PASS] UNDETERMINED declarado como estado terminal legítimo" \
  || { echo "[FAIL] falta UNDETERMINED en docs/INCIDENT_ROOT_CAUSE_MODEL.md"; FAIL=1; }

grep -qi 'nunca se fuerza' "$ROOT/workflows/incident.md" \
  && echo "[PASS] workflows/incident.md declara que nunca se fuerza una conclusión" \
  || { echo "[FAIL] falta la declaración de no forzar conclusión en workflows/incident.md"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] INSUFFICIENT_EVIDENCE/UNDETERMINED tratados como estados legítimos"
exit $FAIL
