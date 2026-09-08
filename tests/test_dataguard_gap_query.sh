#!/usr/bin/env bash
# Q-DG-ARCHIVE-GAP-001 declara V$ARCHIVE_GAP con THREAD# explícito (thread-aware, # 15).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/dataguard/Q-DG-ARCHIVE-GAP-001.md"

[ -f "$Q" ] || { echo "[FAIL] falta Q-DG-ARCHIVE-GAP-001.md"; exit 1; }
grep -q 'V\$ARCHIVE_GAP' "$Q" && echo "[PASS] usa V\$ARCHIVE_GAP" || { echo "[FAIL] falta V\$ARCHIVE_GAP"; FAIL=1; }
block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$Q")
echo "$block" | grep -qi 'thread#' && echo "[PASS] selecciona thread# (thread-aware)" || { echo "[FAIL] falta thread#"; FAIL=1; }

exit $FAIL
