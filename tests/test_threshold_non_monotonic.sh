#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 78/44 (# 1018-1035 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/threshold-crossing/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'NON_MONOTONIC' "$S" && echo "[PASS] declara el estado NON_MONOTONIC" || { echo "[FAIL] falta NON_MONOTONIC"; FAIL=1; }
exit $FAIL
