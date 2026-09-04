#!/usr/bin/env bash
# Valida que manifest.yaml liste explícitamente las capacidades de escritura prohibidas, y que
# ningún archivo del agente declare una capacidad de ejecución/escritura real.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
DIR="$ROOT/agents/oracle-performance-analyst"
M="$DIR/manifest.yaml"

for cap in "KILL SESSION" "ALTER SYSTEM" "SQL Tuning Advisor" "DBMS_ADVISOR.EXECUTE_TASK"; do
  if grep -qF "$cap" "$M"; then
    echo "[PASS] manifest.yaml prohíbe explícitamente: $cap"
  else
    echo "[FAIL] manifest.yaml no prohíbe explícitamente: $cap"
    FAIL=1
  fi
done

grep -q '^security_mode: READ_ONLY_ALWAYS$' "$M" && echo "[PASS] security_mode: READ_ONLY_ALWAYS" || { echo "[FAIL] falta security_mode: READ_ONLY_ALWAYS"; FAIL=1; }

# Ningún archivo .yaml/.md del agente declara un mecanismo real de ejecución (execute/run_command/shell).
if grep -rEiq 'execute_command|run_shell|subprocess\.run|os\.system' "$DIR"/*.yaml "$DIR"/*.md 2>/dev/null; then
  echo "[FAIL] el agente declara un mecanismo de ejecución real"
  FAIL=1
else
  echo "[PASS] ningún archivo del agente declara un mecanismo de ejecución real"
fi

exit $FAIL
