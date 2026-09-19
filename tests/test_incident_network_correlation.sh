#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: incident/network-correlation trata
# ORA-12537/ORA-12170 como síntomas, usando los fixtures correspondientes como referencia.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/incident/network-correlation/SKILL.md"
F1="$ROOT/tests/fixtures/incident/oracle/ora-12537-connection-lost.txt"
F2="$ROOT/tests/fixtures/incident/oracle/ora-12170-connect-timeout.txt"

for f in "$F1" "$F2"; do
  [ -f "$f" ] || { echo "[FAIL] falta el fixture $f"; FAIL=1; }
done

grep -q 'ORA-12537' "$SKILL" \
  && echo "[PASS] incident/network-correlation referencia ORA-12537" \
  || { echo "[FAIL] falta la referencia ORA-12537"; FAIL=1; }

grep -qi 'nunca causa raíz automática' "$SKILL" \
  && echo "[PASS] declara que los errores TNS nunca son causa raíz automática" \
  || { echo "[FAIL] falta la regla de no-causa-automática"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] incident/network-correlation consistente con los fixtures TNS"
exit $FAIL
