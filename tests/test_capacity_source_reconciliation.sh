#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 79/52 (# 1167-1188 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/capacity-assessment/SKILL.md"
FX="$ROOT/tests/fixtures/capacity-source-conflict-cpu.yaml"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta fixture $FX"; exit 1; }
grep -q 'preferred source' "$S" && echo "[PASS] declara preferred source/secondary source/reconciliation rule" || { echo "[FAIL] falta preferred source"; FAIL=1; }
grep -q 'reconciliation_rule_declared: true' "$FX" && echo "[PASS] fixture declara la regla de reconciliación" || { echo "[FAIL] fixture no declara reconciliation_rule_declared: true"; FAIL=1; }
exit $FAIL
