#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: recovery_status y el estado de intake
# nunca colapsan en un único campo — modelos separados (docs/INCIDENT_INTAKE_MODEL.md vs
# docs/INCIDENT_IMPACT_MODEL.md).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

grep -q 'OPEN|INVESTIGATING|RESOLVED|CLOSED' "$ROOT/docs/INCIDENT_INTAKE_MODEL.md" \
  && echo "[PASS] intake status enum presente" \
  || { echo "[FAIL] falta el enum de intake status"; FAIL=1; }

grep -q 'RECOVERED | PARTIALLY_RECOVERED | STABLE_WITH_RISK | NOT_RECOVERED | UNKNOWN' \
  "$ROOT/docs/INCIDENT_IMPACT_MODEL.md" \
  && echo "[PASS] recovery_status enum presente y distinto del intake status" \
  || { echo "[FAIL] falta el enum de recovery_status"; FAIL=1; }

grep -q 'recovery_status: RECOVERED|PARTIALLY_RECOVERED|STABLE_WITH_RISK|NOT_RECOVERED|UNKNOWN' \
  "$ROOT/skills/incident/recovery-status/SKILL.md" \
  && echo "[PASS] incident/recovery-status/SKILL.md declara el output schema" \
  || { echo "[FAIL] falta el output schema en incident/recovery-status/SKILL.md"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Modelos de status de incidente y de recuperación separados y consistentes"
exit $FAIL
