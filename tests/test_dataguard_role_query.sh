#!/usr/bin/env bash
# Q-DG-ROLE-001 declara V$DATABASE con las columnas de role discovery robusto (# 9).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/dataguard/Q-DG-ROLE-001.md"

[ -f "$Q" ] || { echo "[FAIL] falta Q-DG-ROLE-001.md"; exit 1; }
grep -q 'V\$DATABASE' "$Q" && echo "[PASS] Q-DG-ROLE-001 usa V\$DATABASE" || { echo "[FAIL] falta V\$DATABASE"; FAIL=1; }
block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$Q")
for col in database_role open_mode switchover_status protection_mode protection_level force_logging flashback_on; do
  echo "$block" | grep -qi "$col" && echo "[PASS] Q-DG-ROLE-001 selecciona $col" || { echo "[FAIL] falta columna $col"; FAIL=1; }
done

exit $FAIL
