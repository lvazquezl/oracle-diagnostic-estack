#!/usr/bin/env bash
# Valida que la variante POR DEFECTO (routine monitoring) de Q-DISC-ASM-001 use
# V$ASM_DISKGROUP_STAT, nunca V$ASM_DISKGROUP (que puede disparar disk discovery).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
F="$ROOT/queries/oracle/discovery/Q-DISC-ASM-001.md"

if grep -q 'default: true' "$F"; then
  echo "[PASS] Q-DISC-ASM-001 declara una variante default explícita"
else
  echo "[FAIL] Q-DISC-ASM-001 no declara una variante default"
  FAIL=1
fi

v1=$(awk '/Variant V1/{f=1} f&&/```sql/{c=1;next} c&&/```/{exit} c' "$F" | sed -E 's/--.*$//')
if echo "$v1" | grep -qi 'v\$asm_diskgroup_stat' && ! echo "$v1" | grep -qi 'v\$asm_diskgroup\b'; then
  echo "[PASS] Variante default (V1, routine_stat) usa V\$ASM_DISKGROUP_STAT, no V\$ASM_DISKGROUP"
else
  echo "[FAIL] Variante default no usa exclusivamente V\$ASM_DISKGROUP_STAT"
  FAIL=1
fi

if grep -q 'oracle-discovery-analyst reporta.*V\$ASM_DISKGROUP_STAT\|routine_stat, 11.0+) — DEFAULT' "$F"; then
  echo "[PASS] La variante default está marcada explícitamente como la usada para discovery rutinario"
else
  echo "[FAIL] No se encontró la marca explícita de variante default para discovery rutinario"
  FAIL=1
fi

exit $FAIL
