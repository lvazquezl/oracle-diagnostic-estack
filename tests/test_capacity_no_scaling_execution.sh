#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 80/22-23 (# 610-641 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
H="$ROOT/skills/capacity/horizontal/SKILL.md"
V="$ROOT/skills/capacity/vertical/SKILL.md"

[ -f "$H" ] || { echo "[FAIL] falta $H"; exit 1; }
[ -f "$V" ] || { echo "[FAIL] falta $V"; exit 1; }
grep -q 'nunca ejecuta scale-out de ningún tipo' "$H" && echo "[PASS] capacity/horizontal nunca ejecuta scale-out" || { echo "[FAIL] falta la prohibición de scale-out en horizontal"; FAIL=1; }
grep -q 'sólo recomienda' "$V" && echo "[PASS] capacity/vertical sólo recomienda, nunca ejecuta" || { echo "[FAIL] falta la disciplina sólo-recomienda en vertical"; FAIL=1; }
exit $FAIL
