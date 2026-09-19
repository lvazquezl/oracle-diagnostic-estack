#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: incident/incident-report declara
# UNDETERMINED como hallazgo legítimo y nunca incluye secretos/datos de negocio.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/incident/incident-report/SKILL.md"

grep -qi 'UNDETERMINED' "$SKILL" \
  && echo "[PASS] incident/incident-report declara UNDETERMINED como hallazgo legítimo" \
  || { echo "[FAIL] falta la declaración de UNDETERMINED"; FAIL=1; }

grep -qi 'nunca incluye passwords' "$SKILL" \
  && echo "[PASS] incident/incident-report declara la prohibición de secretos" \
  || { echo "[FAIL] falta la prohibición de secretos en incident-report"; FAIL=1; }

grep -qi 'analysis/ANA-' "$SKILL" \
  && echo "[PASS] incident/incident-report se registra en analysis/ANA-*" \
  || { echo "[FAIL] falta el registro en analysis/ANA-* en incident-report"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] incident/incident-report consistente"
exit $FAIL
