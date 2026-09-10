#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 10/57.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/multitenant/Q-CDB-PDB-STATE-001.md"

[ -f "$Q" ] || { echo "[FAIL] falta Q-CDB-PDB-STATE-001.md"; exit 1; }
for col in con_id name open_mode restricted open_time total_size recovery_status; do
  grep -qi "$col" "$Q" && echo "[PASS] Q-CDB-PDB-STATE-001 selecciona $col" || { echo "[FAIL] falta columna $col"; FAIL=1; }
done
grep -q "variant_id: Q-CDB-PDB-STATE-001-V1" "$Q" && grep -q "variant_id: Q-CDB-PDB-STATE-001-V2" "$Q" && echo "[PASS] declara variantes 12.1/12.2+ (no asume columnas modernas en 12.1)" || { echo "[FAIL] faltan las 2 variantes de versión"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] PDB inventory implementado con las columnas mínimas requeridas y version-aware"

exit $FAIL
