#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: incident/hypothesis-generation aplica un
# límite Top-N configurable, nunca decenas de hipótesis irrelevantes.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/incident/hypothesis-generation/SKILL.md"

[ -f "$SKILL" ] || { echo "[FAIL] falta $SKILL"; FAIL=1; }

grep -q 'incident.max_hypotheses' "$SKILL" \
  && echo "[PASS] incident/hypothesis-generation referencia incident.max_hypotheses" \
  || { echo "[FAIL] falta la referencia a incident.max_hypotheses"; FAIL=1; }

grep -q 'max_hypotheses' "$ROOT/docs/TARGET_PROFILE.md" \
  && echo "[PASS] docs/TARGET_PROFILE.md declara max_hypotheses" \
  || { echo "[FAIL] falta max_hypotheses en docs/TARGET_PROFILE.md"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] incident/hypothesis-generation aplica límite Top-N configurable"
exit $FAIL
