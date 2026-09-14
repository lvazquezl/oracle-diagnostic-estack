#!/usr/bin/env bash
# PHASE 8 — SECURITY QUERY COMPATIBILITY, ORACLE NET EVIDENCE & STATIC VALIDATOR HARDENING,
# secciones 9-12/57. Control positivo de test_dba_users_last_login_12101_invalid.sh — LAST_LOGIN
# sí está certificada desde 12.1.0.2 (verificado WebSearch/WebFetch).
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

min=$(get_col_min "DBA_USERS" "last_login")
[ -z "$min" ] && { echo "[FAIL] DBA_USERS.last_login no está registrada en el dictionary"; exit 1; }

if version_gte "12.1.0.2" "$min"; then
  echo "[PASS] CERTIFIED en 12.1.0.2: last_login correctamente aceptada (min_version=$min)"
else
  echo "[FAIL] el dictionary rechaza last_login en 12.1.0.2 (min_version=$min) — debería estar disponible"
  FAIL=1
fi

exit $FAIL
