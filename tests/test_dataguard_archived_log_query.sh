#!/usr/bin/env bash
# Q-DG-ARCHIVED-LOG-001 siempre parametrizada por ventana de tiempo (# 55 — nunca scan ilimitado).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/dataguard/Q-DG-ARCHIVED-LOG-001.md"

[ -f "$Q" ] || { echo "[FAIL] falta Q-DG-ARCHIVED-LOG-001.md"; exit 1; }
grep -q 'V\$ARCHIVED_LOG' "$Q" && echo "[PASS] usa V\$ARCHIVED_LOG" || { echo "[FAIL] falta V\$ARCHIVED_LOG"; FAIL=1; }
block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$Q")
echo "$block" | grep -q ':time_window_hours' && echo "[PASS] parametrizada por ventana de tiempo" || { echo "[FAIL] falta parametrización de ventana — riesgo de scan ilimitado"; FAIL=1; }
grep -q 'cost_class: MEDIUM' "$Q" && echo "[PASS] cost_class MEDIUM (refleja el costo potencial de V\$ARCHIVED_LOG)" || { echo "[FAIL] cost_class incorrecto"; FAIL=1; }

exit $FAIL
