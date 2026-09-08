#!/usr/bin/env bash
# Q-DG-SRL-001 declara V$STANDBY_LOG agrupado por thread#.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/dataguard/Q-DG-SRL-001.md"

[ -f "$Q" ] || { echo "[FAIL] falta Q-DG-SRL-001.md"; exit 1; }
grep -q 'V\$STANDBY_LOG' "$Q" && echo "[PASS] usa V\$STANDBY_LOG" || { echo "[FAIL] falta V\$STANDBY_LOG"; FAIL=1; }
block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$Q")
echo "$block" | grep -qi 'GROUP.*BY.*thread#' && echo "[PASS] agrupa por thread#" || { echo "[FAIL] falta GROUP BY thread#"; FAIL=1; }

exit $FAIL
