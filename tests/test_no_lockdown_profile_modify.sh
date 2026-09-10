#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 62.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
MANIFEST="$ROOT/agents/oracle-multitenant-analyst/manifest.yaml"
Q="$ROOT/queries/multitenant/Q-CDB-LOCKDOWN-001.md"
SKILL="$ROOT/skills/multitenant/lockdown-profiles/SKILL.md"

grep -qiE "lockdown profile" "$MANIFEST" && echo "[PASS] manifest prohíbe modificación de lockdown profiles" || { echo "[FAIL] falta la prohibición de modificación de lockdown profiles"; FAIL=1; }

for f in "$Q" "$SKILL"; do
  [ -f "$f" ] || { echo "[FAIL] $f no existe"; FAIL=1; continue; }
  if grep -qiE "^\s*ALTER LOCKDOWN PROFILE" "$f"; then
    echo "[FAIL] $f contiene una sentencia ejecutable ALTER LOCKDOWN PROFILE"
    FAIL=1
  fi
done

grep -qi "cdb_lockdown_profiles" "$Q" && echo "[PASS] Q-CDB-LOCKDOWN-001 sólo lee CDB_LOCKDOWN_PROFILES" || { echo "[FAIL] falta la lectura de sólo consulta sobre CDB_LOCKDOWN_PROFILES"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Ninguna capacidad real de ALTER LOCKDOWN PROFILE"

exit $FAIL
