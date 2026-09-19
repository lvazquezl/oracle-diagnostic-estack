#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: CHANGE_CORRELATED != CHANGE_CAUSED,
# distinción estructural nunca colapsada — usa el fixture de resize+stabilization como referencia.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/incident/change-correlation/SKILL.md"
FIXTURE="$ROOT/tests/fixtures/incident/capacity/resize-followed-by-stabilization.txt"

[ -f "$FIXTURE" ] || { echo "[FAIL] falta el fixture $FIXTURE"; FAIL=1; }

tr '\n' ' ' < "$SKILL" | grep -qiE 'nunca se promueve a .CHANGE_CAUSED' \
  && echo "[PASS] CHANGE_CORRELATED nunca se promueve automáticamente a CHANGE_CAUSED" \
  || { echo "[FAIL] falta la regla de no promover CHANGE_CORRELATED a CHANGE_CAUSED"; FAIL=1; }

grep -q 'CHANGE_CORRELATED' "$FIXTURE" \
  && echo "[PASS] fixture declara el resultado esperado CHANGE_CORRELATED" \
  || { echo "[FAIL] falta CHANGE_CORRELATED en el fixture"; FAIL=1; }

grep -q 'CHANGE_CAUSED' "$FIXTURE" \
  && echo "[PASS] fixture referencia CHANGE_CAUSED como distinción explícita" \
  || { echo "[FAIL] falta la mención de CHANGE_CAUSED en el fixture"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] CHANGE_CORRELATED y CHANGE_CAUSED distinguidos consistentemente"
exit $FAIL
