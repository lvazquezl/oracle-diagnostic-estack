#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 60.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
FX="$ROOT/tests/fixtures/19c-pdb-plugin-violations.yaml"
SKILL="$ROOT/skills/multitenant/plugin-violations/SKILL.md"

grep -q 'type: "WARNING"' "$FX" && echo "[PASS] fixture incluye una violación WARNING" || { echo "[FAIL] falta el caso WARNING"; FAIL=1; }
grep -q "WARNING|ERROR|PENDING|RESOLVED|UNKNOWN" "$SKILL" && echo "[PASS] skill clasifica los 5 estados" || { echo "[FAIL] falta la clasificación completa"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Clasificación WARNING correctamente implementada"

exit $FAIL
