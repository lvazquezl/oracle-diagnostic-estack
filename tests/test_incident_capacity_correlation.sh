#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: incident/capacity-correlation nunca usa un
# forecast futuro como prueba de causa pasada — usa el fixture threshold-exceeded.txt (histórico).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/incident/capacity-correlation/SKILL.md"
FIXTURE="$ROOT/tests/fixtures/incident/capacity/threshold-exceeded.txt"

[ -f "$FIXTURE" ] || { echo "[FAIL] falta el fixture $FIXTURE"; FAIL=1; }

grep -qi 'capacity-analyst' "$SKILL" \
  && echo "[PASS] referencia a capacity-analyst presente" \
  || { echo "[FAIL] falta la referencia a capacity-analyst"; FAIL=1; }

grep -q '## Forecast is not evidence of past cause' "$SKILL" \
  && echo "[PASS] sección Forecast is not evidence of past cause presente" \
  || { echo "[FAIL] falta la sección de forecast-no-es-causa-pasada"; FAIL=1; }

grep -q 'ALREADY_EXCEEDED' "$FIXTURE" \
  && echo "[PASS] fixture usa evidencia histórica ALREADY_EXCEEDED, no forecast" \
  || { echo "[FAIL] falta ALREADY_EXCEEDED en el fixture"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] incident/capacity-correlation consistente con el fixture histórico"
exit $FAIL
