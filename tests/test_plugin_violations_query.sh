#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 26/57.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/multitenant/Q-CDB-PLUGIN-VIOLATIONS-001.md"

[ -f "$Q" ] || { echo "[FAIL] falta Q-CDB-PLUGIN-VIOLATIONS-001.md"; exit 1; }
for col in con_id time name cause type error_number line message status action; do
  grep -qi "$col" "$Q" && echo "[PASS] Q-CDB-PLUGIN-VIOLATIONS-001 selecciona $col" || { echo "[FAIL] falta columna $col"; FAIL=1; }
done

[ $FAIL -eq 0 ] && echo "[PASS] Q-CDB-PLUGIN-VIOLATIONS-001 implementada con las 10 columnas reales de PDB_PLUG_IN_VIOLATIONS"

exit $FAIL
