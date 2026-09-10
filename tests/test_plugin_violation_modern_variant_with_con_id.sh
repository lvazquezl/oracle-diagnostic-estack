#!/usr/bin/env bash
# PHASE 6 — QUERY COMPATIBILITY & DICTIONARY CERTIFICATION HARDENING, # 17.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/multitenant/Q-CDB-PLUGIN-VIOLATIONS-001.md"

sql_v2=$(awk '/```sql/{n++;next} n==2 && /```/{exit} n==2{print}' "$Q")

if echo "$sql_v2" | grep -qi 'SELECT con_id, time, name, cause'; then
  echo "[PASS] Variant V2 (modern_122plus_con_id) selecciona con_id, time, name, cause..."
else
  echo "[FAIL] Variant V2 no tiene el SELECT esperado (con con_id)"
  FAIL=1
fi

exit $FAIL
