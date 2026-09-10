#!/usr/bin/env bash
# PHASE 6 — QUERY COMPATIBILITY & DICTIONARY CERTIFICATION HARDENING, # 4-5, # 9.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/multitenant/Q-CDB-PDB-SAVED-STATE-001.md"

grep -qi '^objects_accessed: \[DBA_PDB_SAVED_STATES\]' "$Q" && echo "[PASS] objects_accessed declara DBA_PDB_SAVED_STATES" || { echo "[FAIL] objects_accessed no declara DBA_PDB_SAVED_STATES"; FAIL=1; }

grep -qi 'FROM   dba_pdb_saved_states' "$Q" && echo "[PASS] la sentencia SQL selecciona FROM dba_pdb_saved_states" || { echo "[FAIL] la sentencia SQL no usa dba_pdb_saved_states"; FAIL=1; }

if grep -qi 'FROM   cdb_pdb_saved_states' "$Q"; then
  echo "[FAIL] la query todavía referencia cdb_pdb_saved_states (vista inexistente)"
  FAIL=1
else
  echo "[PASS] la query ya no referencia cdb_pdb_saved_states"
fi

exit $FAIL
