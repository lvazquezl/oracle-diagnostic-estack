#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 13/59.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/multitenant/pdb-rac-placement/SKILL.md"
AGENT="$ROOT/agents/oracle-multitenant-analyst/AGENT.md"

grep -qi "nunca asumir que una PDB debe estar abierta en todas las instancias" "$SKILL" && echo "[PASS] skill declara explícitamente que no asume apertura en todas las instancias" || { echo "[FAIL] falta la declaración explícita en el skill"; FAIL=1; }
grep -qi "nunca asume que una PDB debe estar abierta en todas las instancias" "$AGENT" && echo "[PASS] AGENT.md refuerza la misma regla" || { echo "[FAIL] falta la regla en AGENT.md"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Nunca se asume que una PDB debe estar abierta en todas las instancias RAC"

exit $FAIL
