#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 78/44 (# 1018-1035 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/threshold-crossing/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'DATE_ESTIMATED' "$S" && echo "[PASS] declara el estado DATE_ESTIMATED" || { echo "[FAIL] falta DATE_ESTIMATED"; FAIL=1; }
grep -q 'estimated_date: string|null' "$S" && echo "[PASS] declara estimated_date en el esquema" || { echo "[FAIL] falta estimated_date"; FAIL=1; }
exit $FAIL
