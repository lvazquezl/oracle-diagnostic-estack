#!/usr/bin/env bash
# PHASE 5 — DATA GUARD FINAL PROCESS-VIEW & PORTABILITY HARDENING, sección 11.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/dataguard/Q-DG-MANAGED-PROCESS-001.md"

grep -q 'variant_id: Q-DG-MANAGED-PROCESS-001-V1' "$Q" && echo "[PASS] variante legacy (V1, legacy_managed_standby) declarada" || { echo "[FAIL] falta la variante legacy V1"; FAIL=1; }
grep -qE 'min: "10\.2", max: "12\.1"' "$Q" && echo "[PASS] la variante legacy declara el rango real 10.2-12.1 (V\$MANAGED_STANDBY deprecada desde 12.2.0.1)" || { echo "[FAIL] la variante legacy no declara el rango corregido 10.2-12.1"; FAIL=1; }

block=$(awk '/^# .*Variant V1 \(legacy_managed_standby/{flag=1} flag && /```sql/{c++} flag && c==1 && /```sql/{f2=1;next} f2 && /```/{f2=0} f2' "$Q")
echo "$block" | grep -qi 'v\$managed_standby' && echo "[PASS] variante legacy usa V\$MANAGED_STANDBY" || { echo "[FAIL] la variante legacy no usa V\$MANAGED_STANDBY"; FAIL=1; }
echo "$block" | grep -qi 'process, pid, status, client_process, client_pid, thread#, sequence#, block#, blocks' && echo "[PASS] variante legacy usa las 9 columnas reales documentadas (incluye thread#/client_pid)" || { echo "[FAIL] la variante legacy no tiene las columnas reales esperadas"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Variante legacy de Q-DG-MANAGED-PROCESS-001 correctamente definida"

exit $FAIL
