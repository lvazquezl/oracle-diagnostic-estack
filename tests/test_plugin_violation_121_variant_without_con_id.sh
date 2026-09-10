#!/usr/bin/env bash
# PHASE 6 — QUERY COMPATIBILITY & DICTIONARY CERTIFICATION HARDENING, # 15-16.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/multitenant/Q-CDB-PLUGIN-VIOLATIONS-001.md"

sql_v1=$(awk '/```sql/{n++;next} n==1 && /```/{exit} n==1{print}' "$Q")

if echo "$sql_v1" | grep -qi 'SELECT time, name, cause'; then
  echo "[PASS] Variant V1 (legacy_121_no_con_id) selecciona time/name/cause... sin con_id"
else
  echo "[FAIL] Variant V1 no tiene el SELECT esperado (sin con_id)"
  FAIL=1
fi

if echo "$sql_v1" | grep -qiw 'con_id'; then
  echo "[FAIL] Variant V1 (legacy) selecciona con_id — no debería, no existe en 12.1"
  FAIL=1
else
  echo "[PASS] Variant V1 (legacy) no selecciona con_id"
fi

exit $FAIL
