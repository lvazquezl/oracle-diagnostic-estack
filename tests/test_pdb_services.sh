#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 14/57.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/multitenant/Q-CDB-SERVICES-001.md"
SKILL="$ROOT/skills/multitenant/pdb-services/SKILL.md"

[ -f "$Q" ] || { echo "[FAIL] falta Q-CDB-SERVICES-001.md"; exit 1; }
grep -qi "con_id" "$Q" && grep -qi "clb_goal" "$Q" && grep -qi "active_instance" "$Q" && echo "[PASS] Q-CDB-SERVICES-001 selecciona con_id/clb_goal/instancia activa" || { echo "[FAIL] faltan columnas requeridas"; FAIL=1; }
grep -qi "no modifica servicios" "$SKILL" && echo "[PASS] documenta explícitamente que no modifica servicios" || { echo "[FAIL] falta la prohibición de modificar servicios"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] PDB services implementado correctamente"

exit $FAIL
