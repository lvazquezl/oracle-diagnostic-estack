#!/usr/bin/env bash
# Q-DG-STATS-001 declara V$DATAGUARD_STATS, filtrado a transport lag / apply lag (# 13).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/dataguard/Q-DG-STATS-001.md"

[ -f "$Q" ] || { echo "[FAIL] falta Q-DG-STATS-001.md"; exit 1; }
grep -q 'V\$DATAGUARD_STATS' "$Q" && echo "[PASS] Q-DG-STATS-001 usa V\$DATAGUARD_STATS" || { echo "[FAIL] falta V\$DATAGUARD_STATS"; FAIL=1; }
block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$Q")
echo "$block" | grep -qi "transport lag" && echo "[PASS] filtra transport lag" || { echo "[FAIL] falta filtro transport lag"; FAIL=1; }
echo "$block" | grep -qi "apply lag" && echo "[PASS] filtra apply lag" || { echo "[FAIL] falta filtro apply lag"; FAIL=1; }

exit $FAIL
