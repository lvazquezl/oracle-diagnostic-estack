#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 13/57.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/multitenant/pdb-rac-placement/SKILL.md"

[ -f "$SKILL" ] || { echo "[FAIL] falta skills/multitenant/pdb-rac-placement/SKILL.md"; exit 1; }
grep -qi "configured placement" "$SKILL" && grep -qi "actual open placement" "$SKILL" && grep -qi "service placement" "$SKILL" && echo "[PASS] distingue configured/actual/service placement" || { echo "[FAIL] falta la distinción de los 3 tipos de placement"; FAIL=1; }
grep -qi "nunca asum" "$SKILL" && echo "[PASS] nunca asume que una PDB debe estar en todas las instancias" || { echo "[FAIL] falta la aclaración explícita"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] PDB RAC placement implementado correctamente"

exit $FAIL
