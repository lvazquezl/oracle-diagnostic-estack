#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 16-17/57.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/multitenant/Q-CDB-TABLESPACES-001.md"

[ -f "$Q" ] || { echo "[FAIL] falta Q-CDB-TABLESPACES-001.md"; exit 1; }
grep -qi "used_percent" "$Q" && grep -qi "autoextend" "$Q" && grep -qi "contents" "$Q" && echo "[PASS] selecciona used/autoextend/contents" || { echo "[FAIL] faltan columnas requeridas"; FAIL=1; }
grep -qi "no agrega datafiles" "$Q" && echo "[PASS] documenta que no agrega datafiles" || { echo "[FAIL] falta la prohibición de agregar datafiles"; FAIL=1; }
grep -qi "capacidad física ASM" "$Q" && echo "[PASS] nunca mezcla capacidad ASM con capacidad PDB" || { echo "[FAIL] falta la distinción de capacidad ASM vs PDB"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] PDB tablespaces implementado correctamente"

exit $FAIL
