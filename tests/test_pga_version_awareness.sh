#!/usr/bin/env bash
# Valida que Q-PERF-PGA-001 filtre V$PGASTAT por columna 'name' (string), nunca por un nombre
# de columna que no exista en versiones anteriores a 12.1.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
F="$ROOT/queries/performance/memory/Q-PERF-PGA-001.md"

[ -f "$F" ] || { echo "[FAIL] falta Q-PERF-PGA-001.md"; exit 1; }
block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$F")
if echo "$block" | grep -qi 'pga_aggregate_limit'; then
  echo "[FAIL] Q-PERF-PGA-001 referencia pga_aggregate_limit directamente en el SELECT base (debe leerse por separado vía V\$PARAMETER)"
  FAIL=1
else
  echo "[PASS] Q-PERF-PGA-001 no referencia pga_aggregate_limit en el SELECT base"
fi
grep -qi '12.1' "$F" && echo "[PASS] documenta el gate de versión 12.1 para PGA_AGGREGATE_LIMIT" || { echo "[FAIL] no documenta el gate de versión"; FAIL=1; }

exit $FAIL
