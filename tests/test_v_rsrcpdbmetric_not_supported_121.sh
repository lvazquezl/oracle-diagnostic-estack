#!/usr/bin/env bash
# PHASE 6 — QUERY COMPATIBILITY & DICTIONARY CERTIFICATION HARDENING, # 10-11, # 13.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
DICT="$ROOT/compatibility/oracle-dictionary/views.yaml"
QCM="$ROOT/config/query-compatibility-matrix.yaml"

view_min=$(awk '
  BEGIN{IGNORECASE=1; inview=0}
  /^  [A-Za-z$#0-9_]+:[ \t]*$/{line=$0; sub(/^  /,"",line); sub(/:[ \t]*$/,"",line); inview=(tolower(line)=="v$rsrcpdbmetric")?1:0; next}
  inview && /^    min_version:/{line=$0; sub(/^    min_version:[ \t]*/,"",line); gsub(/"/,"",line); print line; exit}
' "$DICT")

[ "$view_min" = "12.2" ] && echo "[PASS] V\$RSRCPDBMETRIC.min_version = 12.2 en el dictionary (no 12.1)" || { echo "[FAIL] V\$RSRCPDBMETRIC.min_version = '$view_min', esperado 12.2"; FAIL=1; }

qmin=$(grep -A1 'Q-CDB-RESOURCE-USAGE-001:' "$QCM" | grep -oE 'min: "[0-9.]+"' | head -1 | tr -d '"min: ')
qmin_line=$(grep 'Q-CDB-RESOURCE-USAGE-001:' "$QCM")
echo "$qmin_line" | grep -q 'min: "12.2"' && echo "[PASS] query-compatibility-matrix.yaml declara Q-CDB-RESOURCE-USAGE-001 min: 12.2" || { echo "[FAIL] query-compatibility-matrix.yaml no declara min: 12.2 para Q-CDB-RESOURCE-USAGE-001"; FAIL=1; }

echo "$qmin_line" | grep -q 'min: "12.1"' && { echo "[FAIL] query-compatibility-matrix.yaml todavía declara min: 12.1 para Q-CDB-RESOURCE-USAGE-001"; FAIL=1; }

exit $FAIL
