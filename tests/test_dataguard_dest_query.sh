#!/usr/bin/env bash
# Q-DG-DEST-001 declara V$ARCHIVE_DEST/V$ARCHIVE_DEST_STATUS con columnas de clasificación (# 11).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/dataguard/Q-DG-DEST-001.md"

[ -f "$Q" ] || { echo "[FAIL] falta Q-DG-DEST-001.md"; exit 1; }
grep -q 'V\$ARCHIVE_DEST' "$Q" && grep -q 'V\$ARCHIVE_DEST_STATUS' "$Q" && echo "[PASS] Q-DG-DEST-001 usa ambas vistas" || { echo "[FAIL] falta una de las vistas"; FAIL=1; }
block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$Q")
for col in target transmit_mode affirm valid_for; do
  echo "$block" | grep -qi "$col" && echo "[PASS] Q-DG-DEST-001 selecciona $col" || { echo "[FAIL] falta columna $col"; FAIL=1; }
done

exit $FAIL
