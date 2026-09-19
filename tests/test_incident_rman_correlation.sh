#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: incident/rman-correlation nunca ejecuta
# RMAN, usando el fixture fra-pressure-backup-failure.txt como referencia de causal chain.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/incident/rman-correlation/SKILL.md"
FIXTURE="$ROOT/tests/fixtures/incident/rman/fra-pressure-backup-failure.txt"

[ -f "$FIXTURE" ] || { echo "[FAIL] falta el fixture $FIXTURE"; FAIL=1; }

grep -qi 'nunca ejecuta RMAN' "$SKILL" \
  && echo "[PASS] incident/rman-correlation declara que nunca ejecuta RMAN" \
  || { echo "[FAIL] falta la prohibición de ejecutar RMAN"; FAIL=1; }

grep -q 'expected_causal_chain_candidate' "$FIXTURE" \
  && echo "[PASS] fixture declara la cadena causal candidata FRA→archivelog→hang" \
  || { echo "[FAIL] falta la cadena causal en el fixture"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] incident/rman-correlation consistente con el fixture de FRA pressure"
exit $FAIL
