#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 60.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
FX="$ROOT/tests/fixtures/19c-pdb-plugin-violations.yaml"
SKILL="$ROOT/skills/multitenant/plugin-violations/SKILL.md"

grep -q 'type: "ERROR"' "$FX" && echo "[PASS] fixture incluye una violación ERROR" || { echo "[FAIL] falta el caso ERROR"; FAIL=1; }
grep -qi "STATUS=ERROR.*HIGH\|ERROR.*→.*HIGH" "$SKILL" && echo "[PASS] skill clasifica ERROR como severity HIGH" || { echo "[FAIL] falta la severidad HIGH para ERROR"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Clasificación ERROR correctamente implementada"

exit $FAIL
