#!/usr/bin/env bash
# PHASE 5 — DATA GUARD FINAL PROCESS-VIEW & PORTABILITY HARDENING, sección 11-12.
# La variante moderna sólo debe seleccionar columnas registradas para V$DATAGUARD_PROCESS en
# compatibility/oracle-dictionary/views.yaml (columns_exhaustive: true) — verificadas contra la
# documentación oficial de Oracle Database Reference durante este hardening. A diferencia del
# hardening anterior, THREAD#/SEQUENCE#/BLOCK# SÍ son columnas reales de esta vista (corrección
# de un defecto real) — ya no están prohibidas aquí.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/dataguard/Q-DG-MANAGED-PROCESS-001.md"
DICT="$ROOT/compatibility/oracle-dictionary/views.yaml"

valid_cols=$(awk '
  BEGIN{inview=0; incols=0; exhaustive=0}
  /^  V\$DATAGUARD_PROCESS:[ \t]*$/ { inview=1; next }
  /^  [A-Za-z$#0-9_]+:[ \t]*$/ { if (!/^  V\$DATAGUARD_PROCESS:/) inview=0 }
  inview && /^    columns_exhaustive:[ \t]*true[ \t]*$/ { exhaustive=1; next }
  inview && /^    columns:[ \t]*$/ { incols=1; next }
  inview && incols {
    if (!exhaustive) { next }
    if ($0 ~ /^      [A-Za-z_#][A-Za-z0-9_#]*:/) { line=$0; sub(/^      /,"",line); sub(/:.*/,"",line); print tolower(line); next }
    if ($0 ~ /^[ \t]*#/) { next }
    if ($0 ~ /^[ \t]*$/) { incols=0; next }
    incols=0
  }
' "$DICT")

[ -n "$valid_cols" ] && echo "[PASS] V\$DATAGUARD_PROCESS registrada como columns_exhaustive en el dictionary" || { echo "[FAIL] V\$DATAGUARD_PROCESS no está registrada como columns_exhaustive"; FAIL=1; }
echo "$valid_cols" | grep -qx 'thread#' && echo "[PASS] thread# está registrada como columna real de V\$DATAGUARD_PROCESS (corrección respecto al hardening anterior)" || { echo "[FAIL] thread# debería estar registrada"; FAIL=1; }
echo "$valid_cols" | grep -qx 'status' && { echo "[FAIL] 'status' está registrada — no es columna real de V\$DATAGUARD_PROCESS"; FAIL=1; } || echo "[PASS] 'status' correctamente ausente (no es columna de V\$DATAGUARD_PROCESS, pertenece a V\$MANAGED_STANDBY)"
echo "$valid_cols" | grep -qx 'client_process' && { echo "[FAIL] 'client_process' está registrada — no es columna real de V\$DATAGUARD_PROCESS"; FAIL=1; } || echo "[PASS] 'client_process' correctamente ausente (no es columna de V\$DATAGUARD_PROCESS, pertenece a V\$MANAGED_STANDBY)"

block=$(awk '/^# .*Variant V2 \(modern_dataguard_process/{flag=1} flag && /```sql/{c++} flag && c==1 && /```sql/{f2=1;next} f2 && /```/{f2=0} f2' "$Q" | sed -E 's/--.*$//')
selected=$(echo "$block" | tr '\n' ' ' | sed -E 's/.*SELECT //I; s/ FROM .*//I' | tr ',' '\n' | sed -E 's/ +AS +[A-Za-z_][A-Za-z0-9_]*$//I; s/^ *//; s/ *$//' | tr 'A-Z' 'a-z')

while IFS= read -r col; do
  [ -z "$col" ] && continue
  if ! echo "$valid_cols" | grep -qx "$col"; then
    echo "[FAIL] la variante moderna selecciona '$col' — no registrada como columna real de V\$DATAGUARD_PROCESS"
    FAIL=1
  fi
done <<< "$selected"

for should_have in name pid type role action client_pid client_role thread# sequence# block# block_count; do
  if ! echo "$block" | grep -qi "$should_have"; then
    echo "[FAIL] la variante moderna no selecciona '$should_have' — se esperaba (# 4 del prompt: mínimo de columnas a validar)"
    FAIL=1
  fi
done

[ $FAIL -eq 0 ] && echo "[PASS] La variante moderna sólo usa columnas realmente documentadas de V\$DATAGUARD_PROCESS, incluyendo thread#/sequence#/block#"

exit $FAIL
