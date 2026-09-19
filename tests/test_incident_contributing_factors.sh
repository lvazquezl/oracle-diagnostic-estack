#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: incident/contributing-factors declara el
# enum de 5 roles y permanece estructuralmente separado de root_cause.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/incident/contributing-factors/SKILL.md"

for role in AMPLIFIER PRECONDITION LATENT_RISK RECOVERY_DELAY OBSERVABILITY_GAP; do
  grep -q "$role" "$SKILL" || { echo "[FAIL] falta el rol $role en incident/contributing-factors/SKILL.md"; FAIL=1; }
done

grep -qi 'separados estructuralmente de.*root_cause\|nunca mezclados' "$ROOT/docs/INCIDENT_ROOT_CAUSE_MODEL.md" \
  && echo "[PASS] contributing factors declarados como estructuralmente separados de root_cause" \
  || { echo "[FAIL] falta la separación estructural de contributing factors"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] incident/contributing-factors completo y separado de root_cause"
exit $FAIL
