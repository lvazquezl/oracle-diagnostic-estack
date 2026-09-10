#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 62.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
MANIFEST="$ROOT/agents/oracle-multitenant-analyst/manifest.yaml"
SKILL="$ROOT/skills/multitenant/pdb-state/SKILL.md"
Q="$ROOT/queries/multitenant/Q-CDB-PDB-SAVED-STATE-001.md"

grep -qiE "SAVE STATE|DISCARD STATE" "$MANIFEST" && echo "[PASS] manifest prohíbe SAVE STATE / DISCARD STATE" || { echo "[FAIL] falta la prohibición de SAVE STATE / DISCARD STATE"; FAIL=1; }

grep -qi "cdb_pdb_saved_states" "$Q" && echo "[PASS] Q-CDB-PDB-SAVED-STATE-001 sólo lee CDB_PDB_SAVED_STATES (visibilidad, no ejecución)" || { echo "[FAIL] falta la query de sólo lectura sobre CDB_PDB_SAVED_STATES"; FAIL=1; }

for f in "$Q" "$SKILL"; do
  [ -f "$f" ] || continue
  if grep -qiE "^\s*(ALTER PLUGGABLE DATABASE.*SAVE STATE|ALTER PLUGGABLE DATABASE.*DISCARD STATE)" "$f"; then
    echo "[FAIL] $f contiene una sentencia ejecutable de SAVE/DISCARD STATE"
    FAIL=1
  fi
done

[ $FAIL -eq 0 ] && echo "[PASS] Ninguna capacidad real de ejecutar SAVE STATE / DISCARD STATE"

exit $FAIL
