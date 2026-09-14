#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 72.
# Nombre domain-prefixed (tests/test_no_arbitrary_sql.sh ya existe, propiedad de Data Guard,
# scoped a queries/dataguard — mismo patrón que tests/test_rman_no_arbitrary_sql.sh en Fase 7).
# Ninguna query Security acepta SQL de texto libre — sólo binds ya documentados.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
ALLOWED_BINDS=":function_owner :function_name :time_window_days :max_rows"

for f in $(find "$ROOT/queries/security" -name 'Q-*.md' 2>/dev/null); do
  block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$f")
  binds=$(echo "$block" | grep -oE ':[a-z_]+' | sort -u)
  for b in $binds; do
    case " $ALLOWED_BINDS " in
      *" $b "*) ;;
      *) echo "[FAIL] $f usa bind variable no documentado: $b"; FAIL=1 ;;
    esac
  done
done
[ $FAIL -eq 0 ] && echo "[PASS] Ninguna query Security acepta SQL/parámetros no acotados"

grep -qi "execute_sql(command) / run_sql(command) / arbitrary_sql_shell(command)" "$ROOT/agents/oracle-security-analyst/manifest.yaml" \
  && echo "[PASS] manifest prohíbe wrappers de SQL arbitrario" \
  || { echo "[FAIL] falta la prohibición de SQL arbitrario"; FAIL=1; }

exit $FAIL
