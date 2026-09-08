#!/usr/bin/env bash
# PHASE 5 — DATA GUARD FINAL PROCESS-VIEW & PORTABILITY HARDENING, sección 11.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/dataguard/Q-DG-MANAGED-PROCESS-001.md"

grep -q 'variant_id: Q-DG-MANAGED-PROCESS-001-V2' "$Q" && echo "[PASS] variante moderna (V2, modern_dataguard_process) declarada" || { echo "[FAIL] falta la variante moderna V2"; FAIL=1; }
grep -qE 'min: "12\.2", max: "23\.0"' "$Q" && echo "[PASS] la variante moderna declara min 12.2 (versión real de introducción de V\$DATAGUARD_PROCESS, corregido desde 11.2)" || { echo "[FAIL] la variante moderna no declara el rango corregido 12.2-23.0"; FAIL=1; }

block=$(awk '/^# .*Variant V2 \(modern_dataguard_process/{flag=1} flag && /```sql/{c++} flag && c==1 && /```sql/{f2=1;next} f2 && /```/{f2=0} f2' "$Q")
echo "$block" | grep -qi 'v\$dataguard_process' && echo "[PASS] variante moderna usa V\$DATAGUARD_PROCESS" || { echo "[FAIL] la variante moderna no usa V\$DATAGUARD_PROCESS"; FAIL=1; }
echo "$block" | grep -qi 'name, pid, type, role, action, client_pid, client_role, thread#, sequence#, block#, block_count' && echo "[PASS] variante moderna usa las 11 columnas reales documentadas" || { echo "[FAIL] la variante moderna no tiene las columnas reales esperadas"; FAIL=1; }
echo "$block" | grep -qiE '\bstatus\b|\bclient_process\b' && { echo "[FAIL] la variante moderna todavía selecciona status/client_process — no son columnas de V\$DATAGUARD_PROCESS"; FAIL=1; } || echo "[PASS] la variante moderna ya no selecciona status/client_process (no existen en V\$DATAGUARD_PROCESS)"

grep -qi 'process_role.*NOT_AVAILABLE\|NOT_AVAILABLE.*process_role' "$Q" && echo "[PASS] process_role queda NOT_AVAILABLE en la variante legacy — no se inventa un valor" || { echo "[FAIL] falta la marca NOT_AVAILABLE para process_role"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Variante moderna de Q-DG-MANAGED-PROCESS-001 usa columnas reales documentadas de V\$DATAGUARD_PROCESS"

exit $FAIL
