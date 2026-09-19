#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: incident/change-correlation clasifica
# CHANGE_CORRELATED/CHANGE_CAUSED/NO_CORRELATION usando una ventana configurable, nunca
# hardcodeada, y usa el fixture de ORA-04068 (deployment correlacionado) como escenario de referencia.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/incident/change-correlation/SKILL.md"
FIXTURE="$ROOT/tests/fixtures/incident/oracle/ora-04068-package-state-invalid.txt"

[ -f "$FIXTURE" ] || { echo "[FAIL] falta el fixture $FIXTURE"; FAIL=1; }

for status in CHANGE_CORRELATED CHANGE_CAUSED NO_CORRELATION; do
  grep -q "$status" "$SKILL" || { echo "[FAIL] falta el estado $status en incident/change-correlation/SKILL.md"; FAIL=1; }
done

grep -qi 'incident.change_correlation' "$SKILL" \
  && echo "[PASS] incident/change-correlation referencia la ventana configurable del Target Profile" \
  || { echo "[FAIL] falta la referencia a incident.change_correlation"; FAIL=1; }

grep -q 'expected_change_correlation: CHANGE_CORRELATED' "$FIXTURE" \
  && echo "[PASS] fixture ORA-04068 declara el resultado esperado CHANGE_CORRELATED" \
  || { echo "[FAIL] falta expected_change_correlation en el fixture"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] incident/change-correlation consistente con el fixture de referencia"
exit $FAIL
