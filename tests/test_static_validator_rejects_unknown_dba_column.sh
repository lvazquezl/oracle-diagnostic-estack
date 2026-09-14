#!/usr/bin/env bash
# PHASE 8 — SECURITY QUERY COMPATIBILITY, ORACLE NET EVIDENCE & STATIC VALIDATOR HARDENING,
# secciones 19-20/57. Fixture negativo/positivo controlado (NUNCA agregado a queries/, sólo en
# memoria/temp aquí — mismo patrón que test_static_validator_detects_invalid_vdatabase_column.sh).
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

valid_cols=$(get_view_columns "DBA_USERS")

# 19. NEGATIVE FIXTURE — UNKNOWN DBA COLUMN: "SELECT fake_security_column FROM dba_users;"
FAKE_SQL="SELECT fake_security_column FROM dba_users;"
fake_col=$(echo "$FAKE_SQL" | sed -E 's/.*SELECT //I; s/ FROM .*//I' | tr 'A-Z' 'a-z' | sed -E 's/^ *//; s/ *$//')
if echo "$valid_cols" | grep -qx "$fake_col"; then
  echo "[FAIL] el fixture negativo '$fake_col' aparece como válido en DBA_USERS — NOT_CERTIFIED esperado"
  FAIL=1
else
  echo "[PASS] NOT_CERTIFIED: 'fake_security_column' correctamente rechazada sobre DBA_USERS (unqualified, unico source inequívoco)"
fi

# 20. POSITIVE FIXTURE — VALID DBA COLUMN: "SELECT username, account_status FROM dba_users;"
for real_col in username account_status; do
  if echo "$valid_cols" | grep -qx "$real_col"; then
    echo "[PASS] CERTIFIED: '$real_col' (columna real) correctamente aceptada sobre DBA_USERS"
  else
    echo "[FAIL] Control positivo falló — '$real_col' debería existir en DBA_USERS"
    FAIL=1
  fi
done

if grep -rq 'fake_security_column' "$ROOT/queries" --include='Q-*.md' 2>/dev/null; then
  echo "[FAIL] el fixture negativo se filtró al catálogo de queries productivas"
  FAIL=1
else
  echo "[PASS] El fixture negativo permanece fuera del catálogo de queries productivas"
fi

exit $FAIL
