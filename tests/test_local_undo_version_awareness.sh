#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 19-20/57.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
DICT="$ROOT/compatibility/oracle-dictionary/views.yaml"
Q="$ROOT/queries/multitenant/Q-CDB-PDB-STATE-001.md"

vpdbs_block=$(awk '/^  V\$PDBS:[ \t]*$/{flag=1;next} /^  [A-Za-z$#0-9_]+:[ \t]*$/{flag=0} flag' "$DICT")
echo "$vpdbs_block" | grep -q 'local_undo:.*min_version: "12.2"' && echo "[PASS] views.yaml registra local_undo con min_version 12.2 (no 12.1)" || { echo "[FAIL] local_undo no está registrada con min_version 12.2"; FAIL=1; }

v1_block=$(awk '/Variant V1 \(legacy_121/{flag=1} flag && /```sql/{c++} flag && c==1 && /```sql/{f2=1;next} f2 && /```/{f2=0} f2' "$Q")
if echo "$v1_block" | grep -qi "local_undo"; then
  echo "[FAIL] la variante 12.1 de Q-CDB-PDB-STATE-001 selecciona local_undo — no debería, la columna no existe en 12.1"
  FAIL=1
else
  echo "[PASS] la variante 12.1 no selecciona local_undo"
fi

[ $FAIL -eq 0 ] && echo "[PASS] Local Undo es correctamente version-aware — nunca asumido en 12.1"

exit $FAIL
