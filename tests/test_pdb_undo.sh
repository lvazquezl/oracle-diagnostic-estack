#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 19/57.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/multitenant/pdb-undo/SKILL.md"

[ -f "$SKILL" ] || { echo "[FAIL] falta skills/multitenant/pdb-undo/SKILL.md"; exit 1; }
grep -qi "SHARED" "$SKILL" && grep -qi "LOCAL" "$SKILL" && echo "[PASS] distingue shared undo vs. local undo" || { echo "[FAIL] falta la distinción de modos undo"; FAIL=1; }
grep -qi "no existe en 12.1\|Local Undo no existe" "$SKILL" && echo "[PASS] documenta que Local Undo no existe en 12.1" || { echo "[FAIL] falta la aclaración de versión"; FAIL=1; }
grep -qi "nunca cambia" "$SKILL" && echo "[PASS] nunca cambia LOCAL_UNDO_ENABLED" || { echo "[FAIL] falta la prohibición de cambiar el modo"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] PDB UNDO implementado correctamente"

exit $FAIL
