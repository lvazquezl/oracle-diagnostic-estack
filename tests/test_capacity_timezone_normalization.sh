#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 72/29 (# 743-753 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/data-quality/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'clock/timezone consistency' "$S" && echo "[PASS] evalúa clock/timezone consistency" || { echo "[FAIL] falta clock/timezone consistency"; FAIL=1; }
exit $FAIL
