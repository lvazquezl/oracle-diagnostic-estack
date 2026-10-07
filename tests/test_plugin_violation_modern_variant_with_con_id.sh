#!/usr/bin/env bash
# PHASE 6 — QUERY COMPATIBILITY & DICTIONARY CERTIFICATION HARDENING. CHG-ESTACK-PDB-COVERAGE-001 (4.0.0): la V2 (12.2+)
# resume por con_id, nombre de PDB, tipo, estado y causa.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/multitenant/Q-CDB-PLUGIN-VIOLATIONS-001.md"

sql_v2=$(awk '/```sql/{n++;next} n==2 && /```/{exit} n==2{print}' "$Q")

if grep -qi 'SELECT con_id, name AS pdb_name, type, status, cause' <<<"$sql_v2"; then
  echo "[PASS] Variant V2 (modern_122plus_con_id) resume por con_id, pdb_name, type, status, cause"
else
  echo "[FAIL] Variant V2 no tiene el SELECT esperado (con con_id)"
  FAIL=1
fi

exit $FAIL
