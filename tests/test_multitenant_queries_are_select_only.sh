#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 62 — equivalente Multitenant
# de "no arbitrary SQL" (test_no_arbitrary_sql.sh existente es específico de Data Guard).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
DIR="$ROOT/queries/multitenant"

for f in "$DIR"/*.md; do
  sql=$(sed -n '/```sql/,/```/p' "$f" | sed '1d;$d')
  [ -z "$sql" ] && { echo "[FAIL] $f no tiene bloque SQL"; FAIL=1; continue; }
  first_kw=$(echo "$sql" | grep -vE '^\s*(--|$)' | head -1 | awk '{print toupper($1)}')
  if [ "$first_kw" != "SELECT" ] && [ "$first_kw" != "WITH" ]; then
    echo "[FAIL] $f no comienza con SELECT/WITH (primer keyword: $first_kw)"
    FAIL=1
  fi
  if echo "$sql" | grep -qiE '\b(INSERT|UPDATE|DELETE|MERGE|DROP|TRUNCATE|CREATE|ALTER|GRANT|REVOKE|EXEC|EXECUTE|CALL)\b'; then
    echo "[FAIL] $f contiene una palabra clave de escritura/DDL/DML fuera de un SELECT de sólo lectura"
    FAIL=1
  fi
  if echo "$sql" | grep -qE ':[a-zA-Z_][a-zA-Z0-9_]*'; then
    echo "[FAIL] $f usa bind variables (:param) — no permitido, todas las queries deben ser autocontenidas y de sólo lectura"
    FAIL=1
  fi
done

[ $FAIL -eq 0 ] && echo "[PASS] Las 15 queries de Multitenant son SELECT/WITH puros, sin DML/DDL ni bind variables"

exit $FAIL
