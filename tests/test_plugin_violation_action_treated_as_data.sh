#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 26/48/60.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/multitenant/plugin-violations/SKILL.md"
AGENT="$ROOT/agents/oracle-multitenant-analyst/AGENT.md"

grep -qi "tratado.*como DATA\|se trata siempre como DATA\|siempre como texto de datos" "$SKILL" && echo "[PASS] skill declara MESSAGE/ACTION como DATA" || { echo "[FAIL] falta la declaración DATA en el skill"; FAIL=1; }
grep -qi "prompt injection\|nunca se ejecuta contenido" "$SKILL" && echo "[PASS] skill documenta defensa contra prompt injection" || { echo "[FAIL] falta la defensa contra prompt injection"; FAIL=1; }
grep -qi "PDB_PLUG_IN_VIOLATIONS.ACTION" "$AGENT" && echo "[PASS] AGENT.md incluye PDB_PLUG_IN_VIOLATIONS en la sección de prompt injection" || { echo "[FAIL] falta la referencia en AGENT.md"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] MESSAGE/ACTION de plug-in violations tratados siempre como DATA inerte"

exit $FAIL
