#!/usr/bin/env bash
# PHASE 6 — QUERY COMPATIBILITY & DICTIONARY CERTIFICATION HARDENING. CHG-ESTACK-PDB-COVERAGE-001 (4.0.0): la V1 (12.1)
# es un resumen por nombre de PDB, tipo, estado y causa, sin con_id (no existe en 12.1).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/multitenant/Q-CDB-PLUGIN-VIOLATIONS-001.md"

sql_v1=$(awk '/```sql/{n++;next} n==1 && /```/{exit} n==1{print}' "$Q")

if grep -qi 'SELECT name AS pdb_name, type, status, cause' <<<"$sql_v1"; then
  echo "[PASS] Variant V1 (legacy_121_no_con_id) resume por pdb_name/type/status/cause sin con_id"
else
  echo "[FAIL] Variant V1 no tiene el SELECT esperado (sin con_id)"
  FAIL=1
fi

if grep -qiw 'con_id' <<<"$sql_v1"; then
  echo "[FAIL] Variant V1 (legacy) selecciona con_id — no debería, no existe en 12.1"
  FAIL=1
else
  echo "[PASS] Variant V1 (legacy) no selecciona con_id"
fi

exit $FAIL
