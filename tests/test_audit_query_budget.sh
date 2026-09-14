#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 68/61.
# UNIFIED_AUDIT_TRAIL/DBA_AUDIT_TRAIL nunca se consultan completos por defecto — siempre filtros.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q1="$ROOT/queries/security/Q-SEC-UNIFIED-AUDIT-TRAIL-001.md"
Q2="$ROOT/queries/security/Q-SEC-TRADITIONAL-AUDIT-001.md"

for Q in "$Q1" "$Q2"; do
  grep -q ":time_window_days" "$Q" && grep -q ":max_rows" "$Q" \
    && echo "[PASS] $(basename "$Q") usa binds time_window_days/max_rows obligatorios" \
    || { echo "[FAIL] $(basename "$Q") no acota por tiempo/filas"; FAIL=1; }
done

block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$Q1")
echo "$block" | grep -qi "^\s*SELECT \* FROM\s*unified_audit_trail\s*;" \
  && { echo "[FAIL] Q-SEC-UNIFIED-AUDIT-TRAIL-001 selecciona la tabla completa sin filtro"; FAIL=1; } \
  || echo "[PASS] Q-SEC-UNIFIED-AUDIT-TRAIL-001 no selecciona la tabla completa sin filtro"

exit $FAIL
