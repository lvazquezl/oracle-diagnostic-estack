#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 26/60.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/multitenant/plugin-violations/SKILL.md"

grep -qi "nunca ejecuta la acción sugerida" "$SKILL" && echo "[PASS] skill declara que nunca ejecuta la acción sugerida por la vista" || { echo "[FAIL] falta la prohibición de ejecutar ACTION"; FAIL=1; }
grep -qi "NOT_EXECUTED" "$SKILL" && echo "[PASS] toda corrección usa el Manual Action Contract con NOT_EXECUTED" || { echo "[FAIL] falta la referencia a NOT_EXECUTED"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Ninguna acción de remediación automática para plug-in violations"

exit $FAIL
