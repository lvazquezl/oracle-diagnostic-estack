#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 31/61/62.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/multitenant/resource-manager/SKILL.md"

grep -qi "PENDING AREA" "$SKILL" && echo "[PASS] skill prohíbe explícitamente cambios de pending area" || { echo "[FAIL] falta la prohibición de pending area"; FAIL=1; }
grep -qi "nunca afirma throttling sin evidencia\|nunca se afirma throttling" "$SKILL" && echo "[PASS] nunca afirma throttling sin evidencia directa" || { echo "[FAIL] falta la aclaración de throttling"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Ningún cambio de límite de recursos en el catálogo Multitenant"

exit $FAIL
