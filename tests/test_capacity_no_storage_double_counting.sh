#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 76/14 (# 463-479 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/storage/SKILL.md"
FX="$ROOT/tests/fixtures/capacity-storage-layers-no-double-counting.yaml"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta fixture $FX"; exit 1; }
grep -q 'Storage layer model' "$S" && echo "[PASS] declara el Storage layer model" || { echo "[FAIL] falta Storage layer model"; FAIL=1; }
grep -q 'nunca se suman capas distintas' "$S" && echo "[PASS] declara la disciplina anti-double-counting" || { echo "[FAIL] falta la disciplina anti-double-counting"; FAIL=1; }
grep -q 'double_counting_present_in_output: false' "$FX" && echo "[PASS] fixture confirma ausencia de double counting en el output" || { echo "[FAIL] fixture no confirma la ausencia de double counting"; FAIL=1; }
exit $FAIL
