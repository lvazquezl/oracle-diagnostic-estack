#!/usr/bin/env bash
# PHASE 8 — FINAL DBA_USERS 12.1.0.2 SOURCE-OF-TRUTH CORRECTION.
# Reemplaza a test_dba_users_common_12101_valid.sh (eliminado) — esa aserción resultó incorrecta.
# Verificado en el HTML crudo (curl, sin resumen de modelo) de
# docs.oracle.com/database/121/REFRN/GUID-309FCCB2-...htm (DBA_USERS): footnote oficial verbatim
# "This column is available starting with Oracle Database 12c Release 1 (12.1.0.2)." adjunta
# explícitamente a COMMON (junto con ORACLE_MAINTAINED, LAST_LOGIN, PROXY_ONLY_CONNECT) — la
# columna NO existe en 12.1.0.1, aunque la arquitectura Multitenant (common/local users como
# concepto) sí sea GA de 12.1.0.1 — la FEATURE arquitectónica y la COLUMNA de diccionario que la
# expone vía SQL son cosas distintas. Usa scripts/lib/version.sh (Shared Version Resolver) —
# nunca un comparador local.
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

min=$(get_col_min "DBA_USERS" "common")
[ -z "$min" ] && { echo "[FAIL] DBA_USERS.common no está registrada en el dictionary"; exit 1; }

if version_gte "12.1.0.1" "$min"; then
  echo "[FAIL] el dictionary certifica common como disponible en 12.1.0.1 (min_version=$min) — debería requerir 12.1.0.2 (footnote oficial)"
  FAIL=1
else
  echo "[PASS] NOT_CERTIFIED en 12.1.0.1: common correctamente rechazada (min_version=$min > 12.1.0.1)"
fi

exit $FAIL
