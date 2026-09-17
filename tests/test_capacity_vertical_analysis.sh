#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 80/23 (# 628-641 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/vertical/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'vertical_analysis:' "$S" && echo "[PASS] declara el esquema vertical_analysis" || { echo "[FAIL] falta vertical_analysis:"; FAIL=1; }
grep -q 'increase CPU' "$S" && echo "[PASS] cubre increase CPU/memory/storage/VM allocation" || { echo "[FAIL] falta increase CPU"; FAIL=1; }
exit $FAIL
