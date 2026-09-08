#!/usr/bin/env bash
# PHASE 5 — DATA GUARD COMPATIBILITY & QUERY CERTIFICATION HARDENING, sección 22.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/dataguard/Q-DG-MANAGED-PROCESS-001.md"

block=$(awk '/^# .*Variant V1 \(legacy_managed_standby/{flag=1} flag && /```sql/{c++} flag && c==1 && /```sql/{f2=1;next} f2 && /```/{f2=0} f2' "$Q")

if echo "$block" | grep -qi 'v\$dataguard_process'; then
  echo "[FAIL] la variante legacy (V1) referencia V\$DATAGUARD_PROCESS — no debería, es la vista de la variante moderna"
  FAIL=1
else
  echo "[PASS] la variante legacy (V1) no referencia V\$DATAGUARD_PROCESS"
fi

echo "$block" | grep -qi 'v\$managed_standby' && echo "[PASS] la variante legacy sigue usando exclusivamente V\$MANAGED_STANDBY" || { echo "[FAIL] la variante legacy no usa V\$MANAGED_STANDBY"; FAIL=1; }

exit $FAIL
