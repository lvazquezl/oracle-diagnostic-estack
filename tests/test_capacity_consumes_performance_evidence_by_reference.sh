#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 82/15 (# 481-498 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/oracle/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'oracle-performance-analyst' "$S" && echo "[PASS] capacity/oracle referencia oracle-performance-analyst para SGA/PGA/AWR" || { echo "[FAIL] falta la referencia a oracle-performance-analyst"; FAIL=1; }
grep -q 'nunca licencia asumida por este skill' "$S" && echo "[PASS] capacity/oracle nunca asume licencia AWR por su cuenta" || { echo "[FAIL] falta la disciplina anti-licencia-asumida"; FAIL=1; }
exit $FAIL
