#!/usr/bin/env bash
# PHASE 6 — FINAL PDB IDENTITY & PATCH-LEVEL RESOLVER HARDENING, # 6, # 13, # 39.
# Valida que la variante moderna usa CON_ID + NAME de forma complementaria y declara
# IDENTITY_MISMATCH cuando no correlacionan — nunca oculta la inconsistencia.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/multitenant/plugin-violations/SKILL.md"
Q="$ROOT/queries/multitenant/Q-CDB-PLUGIN-VIOLATIONS-001.md"

grep -qi 'IDENTITY_MISMATCH' "$SKILL" && echo "[PASS] SKILL.md declara el estado IDENTITY_MISMATCH" || { echo "[FAIL] falta IDENTITY_MISMATCH en el skill"; FAIL=1; }
grep -qi 'IDENTITY_MISMATCH' "$Q" && echo "[PASS] Q-CDB-PLUGIN-VIOLATIONS-001.md documenta IDENTITY_MISMATCH" || { echo "[FAIL] falta IDENTITY_MISMATCH en la query"; FAIL=1; }

grep -qi 'nunca se oculta la inconsistencia\|nunca oculta la discrepancia' "$SKILL" && echo "[PASS] SKILL.md declara explícitamente que la inconsistencia nunca se oculta" || { echo "[FAIL] falta la declaración de no ocultar inconsistencias"; FAIL=1; }

sql_v2=$(awk '/```sql/{n++;next} n==2 && /```/{exit} n==2{print}' "$Q")
echo "$sql_v2" | grep -qiw 'con_id' && echo "$sql_v2" | grep -qiw 'name' && echo "[PASS] la variante moderna selecciona con_id y name simultáneamente" || { echo "[FAIL] la variante moderna no selecciona ambas columnas"; FAIL=1; }

exit $FAIL
