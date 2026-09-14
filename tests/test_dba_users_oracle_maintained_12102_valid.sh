#!/usr/bin/env bash
# PHASE 8 — DBA_USERS 12.1.0.2 BOUNDARY CERTIFICATION MICRO-HARDENING, sección 15.
# Control positivo complementario a test_dba_users_oracle_maintained_12101_valid.sh —
# ORACLE_MAINTAINED, disponible desde 12.1.0.1 (verificado WebSearch/WebFetch, ver
# docs/PHASE_8_DBA_USERS_12102_BOUNDARY_CERTIFICATION_HARDENING.md), también es CERTIFIED en
# 12.1.0.2 y en adelante.
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

min=$(get_col_min "DBA_USERS" "oracle_maintained")
[ -z "$min" ] && { echo "[FAIL] DBA_USERS.oracle_maintained no está registrada en el dictionary"; exit 1; }

if version_gte "12.1.0.2" "$min"; then
  echo "[PASS] CERTIFIED en 12.1.0.2: oracle_maintained correctamente aceptada (min_version=$min)"
else
  echo "[FAIL] el dictionary rechaza oracle_maintained en 12.1.0.2 (min_version=$min) — debería estar disponible"
  FAIL=1
fi

exit $FAIL
