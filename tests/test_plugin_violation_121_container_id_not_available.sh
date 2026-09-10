#!/usr/bin/env bash
# PHASE 6 — FINAL PDB IDENTITY & PATCH-LEVEL RESOLVER HARDENING, # 5, # 13, # 39.
# CON_ID sigue NOT_AVAILABLE en 12.1 (no existe la columna) — esto no cambia con la corrección de
# semántica de NAME, sólo container_name/pdb_token dejan de ser null.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/multitenant/plugin-violations/SKILL.md"
Q="$ROOT/queries/multitenant/Q-CDB-PLUGIN-VIOLATIONS-001.md"

grep -q 'container_id: NOT_AVAILABLE' "$SKILL" && echo "[PASS] SKILL.md declara container_id: NOT_AVAILABLE en legacy" || { echo "[FAIL] falta container_id: NOT_AVAILABLE"; FAIL=1; }

sql_v1=$(awk '/```sql/{n++;next} n==1 && /```/{exit} n==1{print}' "$Q")
if echo "$sql_v1" | grep -qiw 'con_id'; then
  echo "[FAIL] la variante legacy todavía selecciona con_id"
  FAIL=1
else
  echo "[PASS] la variante legacy sigue sin seleccionar con_id (columna inexistente en 12.1)"
fi

exit $FAIL
