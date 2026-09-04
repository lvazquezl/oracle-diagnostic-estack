#!/usr/bin/env bash
# Valida que Q-PERF-TOPSQL-001 exista, certificada, sin SQL_TEXT, con Diagnostics Pack.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
F="$ROOT/queries/performance/sql/Q-PERF-TOPSQL-001.md"

[ -f "$F" ] || { echo "[FAIL] falta Q-PERF-TOPSQL-001.md"; exit 1; }
grep -q '^status: active$' "$F" && echo "[PASS] Q-PERF-TOPSQL-001 status: active" || { echo "[FAIL] no está active"; FAIL=1; }
grep -q 'license_requirements: \[Diagnostics Pack\]' "$F" && echo "[PASS] Q-PERF-TOPSQL-001 requiere Diagnostics Pack" || { echo "[FAIL] no declara Diagnostics Pack"; FAIL=1; }
block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$F")
if echo "$block" | grep -Eiq 'SQL_TEXT|SQL_FULLTEXT'; then
  echo "[FAIL] Q-PERF-TOPSQL-001 selecciona SQL_TEXT"
  FAIL=1
else
  echo "[PASS] Q-PERF-TOPSQL-001 no selecciona SQL_TEXT"
fi

exit $FAIL
