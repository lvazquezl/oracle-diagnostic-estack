#!/usr/bin/env bash
# Valida que oracle-multitenant-analyst no declara ningún mecanismo de ejecución real.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
DIR="$ROOT/agents/oracle-multitenant-analyst"
M="$DIR/manifest.yaml"

for cap in "CREATE PLUGGABLE DATABASE" "DROP PLUGGABLE DATABASE" "ALTER PLUGGABLE DATABASE OPEN|CLOSE" "SAVE STATE|DISCARD STATE" "UNPLUG|PLUG|RELOCATE|REFRESH" "ALTER LOCKDOWN PROFILE" "ALTER SYSTEM SET RESOURCE_MANAGER_PLAN"; do
  if grep -qF "$cap" "$M"; then
    echo "[PASS] manifest.yaml prohíbe explícitamente: $cap"
  else
    echo "[FAIL] manifest.yaml no prohíbe explícitamente: $cap"
    FAIL=1
  fi
done

grep -q '^security_mode: READ_ONLY_ALWAYS$' "$M" && echo "[PASS] security_mode: READ_ONLY_ALWAYS" || { echo "[FAIL] falta security_mode: READ_ONLY_ALWAYS"; FAIL=1; }

if grep -rEiq 'execute_command|run_shell|subprocess\.run|os\.system' "$DIR"/*.yaml "$DIR"/*.md 2>/dev/null; then
  echo "[FAIL] el agente declara un mecanismo de ejecución real"
  FAIL=1
else
  echo "[PASS] ningún archivo del agente declara un mecanismo de ejecución real"
fi

exit $FAIL
