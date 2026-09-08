#!/usr/bin/env bash
# PHASE 5 — DATA GUARD FINAL PROCESS-VIEW & PORTABILITY HARDENING, sección 11.
# Espejo de test_dataguard_process_legacy_does_not_use_modern_view.sh: la variante moderna no debe
# referenciar V$MANAGED_STANDBY, y desde este hardening tampoco debe quedar marcada como
# "on_demand_only" — para 12.2+ es la única variante certificada, no un overlay opcional sobre un
# default legacy deprecado (# 8: no usar la vista deprecated como universal permanent default).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/dataguard/Q-DG-MANAGED-PROCESS-001.md"
MATRIX="$ROOT/config/query-compatibility-matrix.yaml"

block=$(awk '/^# .*Variant V2 \(modern_dataguard_process/{flag=1} flag && /```sql/{c++} flag && c==1 && /```sql/{f2=1;next} f2 && /```/{f2=0} f2' "$Q")

if echo "$block" | grep -qi 'v\$managed_standby'; then
  echo "[FAIL] la variante moderna (V2) referencia V\$MANAGED_STANDBY — no debería, es la vista deprecada de la variante legacy"
  FAIL=1
else
  echo "[PASS] la variante moderna (V2) no referencia V\$MANAGED_STANDBY"
fi

echo "$block" | grep -qi 'v\$dataguard_process' && echo "[PASS] la variante moderna sigue usando exclusivamente V\$DATAGUARD_PROCESS" || { echo "[FAIL] la variante moderna no usa V\$DATAGUARD_PROCESS"; FAIL=1; }

mp_section=$(awk '/Q-DG-MANAGED-PROCESS-001:/{flag=1} flag{print} flag && /^  Q-DG-[A-Z-]+-001:/ && !/Q-DG-MANAGED-PROCESS-001:/{exit}' "$MATRIX")
if echo "$mp_section" | grep -q 'on_demand_only: true'; then
  echo "[FAIL] config/query-compatibility-matrix.yaml todavía marca alguna variante on_demand_only — el rango ya no se solapa, no aplica"
  FAIL=1
else
  echo "[PASS] Ninguna variante queda marcada on_demand_only — 12.2+ resuelve directamente a modern, sin overlay opcional sobre un default legacy"
fi

exit $FAIL
