#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: incident/rac-correlation exige evidencia
# en cada eslabón del causal_chain de eviction, usando el fixture node-eviction.txt como referencia.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/incident/rac-correlation/SKILL.md"
FIXTURE="$ROOT/tests/fixtures/incident/rac/node-eviction.txt"

[ -f "$FIXTURE" ] || { echo "[FAIL] falta el fixture $FIXTURE"; FAIL=1; }

grep -qi 'oracle-rac-analyst' "$SKILL" \
  && echo "[PASS] referencia a oracle-rac-analyst presente" \
  || { echo "[FAIL] falta la referencia a oracle-rac-analyst"; FAIL=1; }

grep -qi 'node eviction\|eviction' "$SKILL" \
  && echo "[PASS] incident/rac-correlation cubre eviction" \
  || { echo "[FAIL] falta la cobertura de eviction"; FAIL=1; }

grep -q 'causal_chain' "$FIXTURE" \
  && echo "[PASS] fixture referencia el causal_chain esperado" \
  || { echo "[FAIL] falta el causal_chain en el fixture"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] incident/rac-correlation consistente con el fixture de eviction"
exit $FAIL
