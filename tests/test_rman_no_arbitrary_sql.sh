#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 46.
# Nombre domain-prefixed (tests/test_no_arbitrary_sql.sh ya existe, propiedad de Data Guard,
# scoped a queries/dataguard — mismo patrón que tests/test_performance_no_arbitrary_sql.sh).
# Ninguna query RMAN acepta SQL de texto libre — todas usan bloques SQL fijos certificados, sin
# interpolación de parámetros no validados salvo :session_recid (Q-RMAN-OUTPUT-001), ya acotado.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in $(find "$ROOT/queries/rman" -name 'Q-*.md' 2>/dev/null); do
  block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$f")
  binds=$(echo "$block" | grep -oE ':[a-z_]+' | sort -u)
  for b in $binds; do
    if [ "$b" != ":session_recid" ]; then
      echo "[FAIL] $f usa bind variable no documentado: $b"
      FAIL=1
    fi
  done
done

[ $FAIL -eq 0 ] && echo "[PASS] Ninguna query RMAN acepta SQL/parámetros no acotados"
exit $FAIL
