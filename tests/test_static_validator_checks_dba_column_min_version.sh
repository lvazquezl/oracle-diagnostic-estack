#!/usr/bin/env bash
# PHASE 8 — SECURITY QUERY COMPATIBILITY, ORACLE NET EVIDENCE & STATIC VALIDATOR HARDENING,
# sección 18/57. Fixture negativo controlado (NUNCA agregado a queries/, sólo en memoria/temp
# aquí) reproduciendo el defecto real de Q-SEC-DEFAULT-ACCOUNTS-001 v1.0: un bloque declarando
# target/min version 11.2 que selecciona DBA_USERS.ORACLE_MAINTAINED debe certificarse
# NOT_CERTIFIED. Usa scripts/lib/version.sh (Shared Version Resolver) — nunca un comparador local
# (# 65 del prompt).
#
# PHASE 8 — FINAL DBA_USERS 12.1.0.2 SOURCE-OF-TRUTH CORRECTION: control positivo actualizado de
# target/min=12.1 a target/min=12.1.0.2 — footnote oficial verbatim en docs.oracle.com/database/
# 121/REFRN/.../DBA_USERS (verificado en el HTML crudo, sin resumen de modelo): "This column is
# available starting with Oracle Database 12c Release 1 (12.1.0.2)."
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DICT="$ROOT/compatibility/oracle-dictionary/views.yaml"
source "$ROOT/scripts/lib/version.sh"
FAIL=0

get_col_min() {
  local target="$1" col="$2"
  awk -v target="$target" -v col="$col" '
    BEGIN { IGNORECASE=1; inview=0 }
    /^  [A-Za-z$#0-9_]+:[ \t]*$/ {
      line=$0; sub(/^  /,"",line); sub(/:[ \t]*$/,"",line)
      inview = (tolower(line) == tolower(target)) ? 1 : 0
      next
    }
    inview && $0 ~ ("^      " col ":") {
      line=$0
      sub(/.*min_version:[ \t]*/,"",line)
      sub(/[ \t]*#.*$/,"",line)
      gsub(/"/,"",line)
      sub(/}.*/,"",line)
      sub(/[ \t]*$/,"",line)
      print line
      exit
    }
  ' "$DICT"
}

# 18. NEGATIVE FIXTURE — DBA_USERS WRONG VERSION: "SELECT oracle_maintained FROM dba_users;" con
# target/min declarado 11.2 — reproduce el defecto real de Q-SEC-DEFAULT-ACCOUNTS-001 v1.0.
col_min=$(get_col_min "DBA_USERS" "oracle_maintained")
[ -z "$col_min" ] && { echo "[FAIL] DBA_USERS.oracle_maintained no está registrada"; exit 1; }

target_min="11.2"
if version_gte "$target_min" "$col_min"; then
  echo "[FAIL] target/min=$target_min certificaría oracle_maintained (min_version real=$col_min) — NOT_CERTIFIED esperado"
  FAIL=1
else
  echo "[PASS] NOT_CERTIFIED: bloque con target/min=11.2 que selecciona oracle_maintained (min_version real=$col_min) correctamente rechazado"
fi

# Control positivo: el mismo bloque certificado con target/min=12.1.0.2 (el boundary real) sí pasa.
target_min_ok="12.1.0.2"
if version_gte "$target_min_ok" "$col_min"; then
  echo "[PASS] CERTIFIED: bloque con target/min=12.1.0.2 que selecciona oracle_maintained correctamente aceptado"
else
  echo "[FAIL] target/min=12.1.0.2 debería certificar oracle_maintained (min_version real=$col_min)"
  FAIL=1
fi

# Control negativo adicional: target/min=12.1 (genérico, 12.1.0.1) NO debe certificar —
# exactamente el defecto real corregido en este source-of-truth correction.
target_min_generic="12.1"
if version_gte "$target_min_generic" "$col_min"; then
  echo "[FAIL] target/min=12.1 (genérico) certificaría oracle_maintained (min_version real=$col_min) — NOT_CERTIFIED esperado"
  FAIL=1
else
  echo "[PASS] NOT_CERTIFIED: bloque con target/min=12.1 genérico (equivalente a 12.1.0.1) correctamente rechazado"
fi

exit $FAIL
