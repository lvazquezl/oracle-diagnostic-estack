#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 62.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
MANIFEST="$ROOT/agents/oracle-multitenant-analyst/manifest.yaml"
Q="$ROOT/queries/multitenant/Q-CDB-PARAMETERS-001.md"
SKILL="$ROOT/skills/multitenant/parameters/SKILL.md"

grep -qiE "ALTER SYSTEM SET|ALTER SESSION SET.*parameter|parameter change" "$MANIFEST" \
  && echo "[PASS] manifest prohíbe cambios de parámetros" \
  || { echo "[FAIL] falta la prohibición de cambio de parámetros"; FAIL=1; }

for f in "$Q" "$SKILL"; do
  [ -f "$f" ] || { echo "[FAIL] $f no existe"; FAIL=1; continue; }
  if grep -qiE "^\s*ALTER SYSTEM SET" "$f"; then
    echo "[FAIL] $f contiene una sentencia ejecutable ALTER SYSTEM SET"
    FAIL=1
  fi
done

grep -qi "gv\$system_parameter" "$Q" && echo "[PASS] Q-CDB-PARAMETERS-001 sólo lee GV\$SYSTEM_PARAMETER" || { echo "[FAIL] falta la lectura de sólo consulta sobre GV\$SYSTEM_PARAMETER"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Ninguna capacidad real de ALTER SYSTEM SET a nivel CDB o PDB"

exit $FAIL
