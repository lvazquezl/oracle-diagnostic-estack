#!/usr/bin/env bash
# Valida que ninguna query de queries/performance/sql/ ni queries/performance/plans/ seleccione
# SQL_TEXT/SQL_FULLTEXT por defecto (# 10. SQL TEXT POLICY del prompt de Fase 3).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in $(find "$ROOT/queries/performance/sql" "$ROOT/queries/performance/plans" -name 'Q-*.md'); do
  block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$f" | sed -E 's/--.*$//')
  if echo "$block" | grep -Eiq 'SQL_TEXT|SQL_FULLTEXT'; then
    echo "[FAIL] $f selecciona SQL_TEXT/SQL_FULLTEXT por defecto"
    FAIL=1
  fi
done

if ! grep -q 'SQL TEXT.*NO' "$ROOT/agents/oracle-performance-analyst/AGENT.md"; then
  echo "[FAIL] agents/oracle-performance-analyst/AGENT.md no documenta la política SQL TEXT: NO por defecto"
  FAIL=1
fi

[ $FAIL -eq 0 ] && echo "[PASS] Ninguna query de performance selecciona SQL text por defecto"

exit $FAIL
