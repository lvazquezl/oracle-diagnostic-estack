#!/usr/bin/env bash
# PHASE 5 — DATA GUARD COMPATIBILITY & QUERY CERTIFICATION HARDENING, sección 8/28.
# Prueba que el SQL Static Validator resuelve alias básicos ("SELECT d.col FROM v$archive_dest d")
# sin que el alias oculte una columna inválida ni genere falsos positivos sobre una aliased válida.
# Q-DG-DEST-001 es el caso real del catálogo con JOIN + alias en ambas tablas — se delega al
# validador real (tests/test_sql_static_validator.sh) en vez de duplicar la lógica de resolución.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/dataguard/Q-DG-DEST-001.md"

[ -f "$Q" ] || { echo "[FAIL] falta Q-DG-DEST-001.md"; exit 1; }
grep -qE '^\s*SELECT\s+d\.' "$Q" && grep -q 'JOIN' "$Q" && echo "[PASS] Q-DG-DEST-001 ejercita el caso real de alias básicos (d./s.) sobre un JOIN de dos vistas" || { echo "[FAIL] Q-DG-DEST-001 ya no contiene el caso de alias esperado — actualizar este test"; FAIL=1; }

output=$(bash "$ROOT/tests/test_sql_static_validator.sh")
status=$?

if echo "$output" | grep -q "Q-DG-DEST-001.*referencia columna"; then
  echo "[FAIL] el validador reporta un falso positivo sobre las columnas aliased de Q-DG-DEST-001:"
  echo "$output" | grep "Q-DG-DEST-001"
  FAIL=1
else
  echo "[PASS] El validador no reporta ningún falso positivo sobre las columnas aliased de Q-DG-DEST-001"
fi

if [ "$status" -ne 0 ]; then
  echo "[FAIL] tests/test_sql_static_validator.sh falló en general (exit=$status) — ver salida completa:"
  echo "$output"
  FAIL=1
fi

[ $FAIL -eq 0 ] && echo "[PASS] SQL Static Validator maneja correctamente alias básicos sin ocultar columnas inválidas"

exit $FAIL
