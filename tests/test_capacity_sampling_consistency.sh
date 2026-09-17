#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 72/26 (# 699-700 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/data-quality/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'sampling interval consistency' "$S" && echo "[PASS] evalúa sampling interval consistency" || { echo "[FAIL] falta sampling interval consistency"; FAIL=1; }
exit $FAIL
