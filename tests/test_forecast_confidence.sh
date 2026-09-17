#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 77/41 (# 968-979 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/confidence/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'HIGH`, `MEDIUM`, `LOW`, `INSUFFICIENT`' "$S" && echo "[PASS] declara los 4 estados de confidence" || { echo "[FAIL] faltan los estados HIGH/MEDIUM/LOW/INSUFFICIENT"; FAIL=1; }
grep -q 'no usar sólo un número sin explicación' "$S" && echo "[PASS] declara que nunca se usa sólo un número sin explicación" || { echo "[FAIL] falta la disciplina anti-número-aislado"; FAIL=1; }
exit $FAIL
