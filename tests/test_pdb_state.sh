#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 11/57.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/multitenant/pdb-state/SKILL.md"

[ -f "$SKILL" ] || { echo "[FAIL] falta skills/multitenant/pdb-state/SKILL.md"; exit 1; }
grep -q "MOUNTED|READ WRITE|READ ONLY|MIGRATE|UNKNOWN" "$SKILL" && echo "[PASS] clasifica los 5 estados de open_mode" || { echo "[FAIL] falta la clasificación completa de open_mode"; FAIL=1; }
grep -qi "MOUNTED.*NO es error\|NO es error por sí mismo" "$SKILL" && echo "[PASS] MOUNTED no se trata como error automático" || { echo "[FAIL] falta la aclaración de que MOUNTED no es error por sí mismo"; FAIL=1; }
grep -q "YES|NO|UNKNOWN" "$SKILL" && echo "[PASS] clasifica restricted en 3 estados" || { echo "[FAIL] falta la clasificación de restricted"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] multitenant/pdb-state clasifica correctamente open_mode/restricted sin asumir error automático"

exit $FAIL
