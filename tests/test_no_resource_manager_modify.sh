#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 62.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
MANIFEST="$ROOT/agents/oracle-multitenant-analyst/manifest.yaml"
Q="$ROOT/queries/multitenant/Q-CDB-RESOURCE-MANAGER-001.md"
SKILL="$ROOT/skills/multitenant/resource-manager/SKILL.md"

grep -qiE "RESOURCE_MANAGER_PLAN|DBMS_RESOURCE_MANAGER" "$MANIFEST" \
  && echo "[PASS] manifest prohíbe modificaciones vía DBMS_RESOURCE_MANAGER / RESOURCE_MANAGER_PLAN" \
  || { echo "[FAIL] falta la prohibición de cambios de Resource Manager"; FAIL=1; }

for f in "$Q" "$SKILL"; do
  [ -f "$f" ] || { echo "[FAIL] $f no existe"; FAIL=1; continue; }
  if grep -qiE "DBMS_RESOURCE_MANAGER\.(CREATE|UPDATE|DELETE|SUBMIT_PENDING_AREA)" "$f"; then
    echo "[FAIL] $f contiene una llamada ejecutable a DBMS_RESOURCE_MANAGER"
    FAIL=1
  fi
done

[ $FAIL -eq 0 ] && echo "[PASS] Ninguna capacidad real de modificar el Resource Manager"

exit $FAIL
