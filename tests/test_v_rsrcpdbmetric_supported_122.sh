#!/usr/bin/env bash
# PHASE 6 — QUERY COMPATIBILITY & DICTIONARY CERTIFICATION HARDENING, # 10-13.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
QCM="$ROOT/config/query-compatibility-matrix.yaml"
Q="$ROOT/queries/multitenant/Q-CDB-RESOURCE-USAGE-001.md"

line=$(grep 'Q-CDB-RESOURCE-USAGE-001:' "$QCM")
echo "$line" | grep -q 'min: "12.2"' && echo "$line" | grep -q 'max: "23.0"' && echo "[PASS] Q-CDB-RESOURCE-USAGE-001 cubre 12.2–23.0" || { echo "[FAIL] Q-CDB-RESOURCE-USAGE-001 no cubre 12.2–23.0 correctamente: $line"; FAIL=1; }

grep -qi 'FROM   v\$rsrcpdbmetric' "$Q" && echo "[PASS] la query mantiene su SQL sobre V\$RSRCPDBMETRIC sin cambios para 12.2+" || { echo "[FAIL] la query no selecciona v\$rsrcpdbmetric"; FAIL=1; }

exit $FAIL
