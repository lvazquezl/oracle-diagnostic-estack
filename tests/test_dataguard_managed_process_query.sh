#!/usr/bin/env bash
# Q-DG-MANAGED-PROCESS-001 declara V$MANAGED_STANDBY + variante GV$ para RAC.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/dataguard/Q-DG-MANAGED-PROCESS-001.md"

[ -f "$Q" ] || { echo "[FAIL] falta Q-DG-MANAGED-PROCESS-001.md"; exit 1; }
grep -q 'V\$MANAGED_STANDBY' "$Q" && grep -q 'GV\$MANAGED_STANDBY' "$Q" && echo "[PASS] declara V\$MANAGED_STANDBY y GV\$MANAGED_STANDBY" || { echo "[FAIL] falta una de las dos variantes"; FAIL=1; }
block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$Q")
echo "$block" | grep -qi 'process' && echo "[PASS] selecciona process" || { echo "[FAIL] falta columna process"; FAIL=1; }

exit $FAIL
