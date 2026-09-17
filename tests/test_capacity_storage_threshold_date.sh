#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 75/48 (# 1092-1106 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
T="$ROOT/skills/capacity/threshold-crossing/SKILL.md"

[ -f "$T" ] || { echo "[FAIL] falta $T"; exit 1; }
grep -q 'Storage forecast semantics' "$T" && echo "[PASS] declara Storage forecast semantics" || { echo "[FAIL] falta Storage forecast semantics"; FAIL=1; }
grep -q 'DATE_ESTIMATED' "$T" && echo "[PASS] declara el estado DATE_ESTIMATED" || { echo "[FAIL] falta DATE_ESTIMATED"; FAIL=1; }
exit $FAIL
