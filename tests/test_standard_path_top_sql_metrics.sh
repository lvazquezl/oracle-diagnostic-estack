#!/usr/bin/env bash
# Valida que Q-PERF-TOPSQL-CURRENT-001 (V$SQLSTATS) exista y no requiera licencia.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
F="$ROOT/queries/performance/sql/Q-PERF-TOPSQL-CURRENT-001.md"

[ -f "$F" ] || { echo "[FAIL] falta Q-PERF-TOPSQL-CURRENT-001.md"; exit 1; }
grep -q 'v\$sqlstats' "$F" && echo "[PASS] usa V\$SQLSTATS" || { echo "[FAIL] no usa V\$SQLSTATS"; FAIL=1; }
grep -q 'license_requirements: none' "$F" && echo "[PASS] sin licencia" || { echo "[FAIL] declara licencia"; FAIL=1; }
block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$F")
if echo "$block" | grep -Eiq 'SQL_TEXT|SQL_FULLTEXT'; then
  echo "[FAIL] selecciona SQL_TEXT"
  FAIL=1
else
  echo "[PASS] no selecciona SQL_TEXT"
fi

exit $FAIL
