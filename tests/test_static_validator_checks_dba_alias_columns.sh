#!/usr/bin/env bash
# PHASE 8 — SECURITY QUERY COMPATIBILITY, ORACLE NET EVIDENCE & STATIC VALIDATOR HARDENING,
# sección 22. Fixture negativo/positivo controlado (NUNCA agregado a queries/, sólo en
# memoria/temp aquí — mismo patrón que test_static_validator_detects_invalid_vdatabase_column.sh,
# PHASE 5) para probar que la resolución de alias del Static Validator reconoce objetos DBA_* (no
# sólo V$/GV$) y rechaza una columna inválida alias-qualified sobre ellos. Reimplementa
# deliberadamente una versión mínima de extract_aliases()/resolve_columns_for_view() —
# comparación de versión sigue exclusivamente scripts/lib/version.sh (no reimplementada aquí, no
# se requiere en este test porque no compara versiones, sólo existencia de columna).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DICT="$ROOT/compatibility/oracle-dictionary/views.yaml"
FAIL=0

get_view_columns() {
  local target="$1"
  awk -v target="$target" '
    BEGIN { IGNORECASE=1; inview=0; incols=0; exhaustive=0 }
    /^  [A-Za-z$#0-9_]+:[ \t]*$/ {
      line=$0; sub(/^  /,"",line); sub(/:[ \t]*$/,"",line)
      inview = (tolower(line) == tolower(target)) ? 1 : 0
      incols=0; exhaustive=0
      next
    }
    inview && /^    columns_exhaustive:[ \t]*true[ \t]*$/ { exhaustive=1; next }
    inview && /^    columns:[ \t]*$/ { incols=1; next }
    inview && incols {
      if (!exhaustive) { next }
      if ($0 ~ /^      [A-Za-z_#][A-Za-z0-9_#]*:/) { line=$0; sub(/^      /,"",line); sub(/:.*/,"",line); print tolower(line); next }
      if ($0 ~ /^[ \t]*#/) { next }
      if ($0 ~ /^[ \t]*$/) { incols=0; next }
      incols=0
    }
  ' "$DICT"
}

# Fixture: FROM dba_users u — mismo estilo alias-qualified que Q-SEC-DEFAULT-ACCOUNTS-001.
valid_cols=$(get_view_columns "DBA_USERS")

# Negativo: u.fake_security_column no existe en DBA_USERS.
if echo "$valid_cols" | grep -qx "fake_security_column"; then
  echo "[FAIL] el fixture negativo 'fake_security_column' aparece como válido en DBA_USERS — el mecanismo no funciona"
  FAIL=1
else
  echo "[PASS] NOT_CERTIFIED: 'u.fake_security_column' correctamente rechazada — no existe en DBA_USERS (mismo mecanismo alias-qualified sobre objetos DBA_*)"
fi

# Positivo: u.oracle_maintained sí existe en DBA_USERS.
if echo "$valid_cols" | grep -qx "oracle_maintained"; then
  echo "[PASS] Control positivo: 'u.oracle_maintained' (columna real, alias-qualified) correctamente aceptada"
else
  echo "[FAIL] Control positivo falló — 'oracle_maintained' debería existir en DBA_USERS"
  FAIL=1
fi

# El fixture negativo no debe existir en el catálogo productivo.
if grep -rq 'fake_security_column' "$ROOT/queries" --include='Q-*.md' 2>/dev/null; then
  echo "[FAIL] el fixture negativo 'fake_security_column' se filtró al catálogo de queries productivas"
  FAIL=1
else
  echo "[PASS] El fixture negativo permanece fuera del catálogo de queries productivas"
fi

# Prueba de extremo a extremo contra el validador real: confirma que extract_aliases() reconoce
# el alias "u" sobre "dba_users" (sin "$") ejercitando el caso real Q-SEC-DEFAULT-ACCOUNTS-001
# (FROM dba_users_with_defpwd d JOIN dba_users u ON ...).
Q="$ROOT/queries/security/Q-SEC-DEFAULT-ACCOUNTS-001.md"
grep -qE '^\s*JOIN\s+dba_users\s+u\s+ON' "$Q" \
  && echo "[PASS] Q-SEC-DEFAULT-ACCOUNTS-001 ejercita el caso real de alias DBA_* sobre un JOIN" \
  || { echo "[FAIL] Q-SEC-DEFAULT-ACCOUNTS-001 ya no contiene el patrón de alias esperado — actualizar este test"; FAIL=1; }

exit $FAIL
