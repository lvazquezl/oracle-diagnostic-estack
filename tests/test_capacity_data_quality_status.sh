#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 72/27 (# 712-722 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/data-quality/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'GOOD|ACCEPTABLE|DEGRADED|INSUFFICIENT|INVALID' "$S" && echo "[PASS] declara los 5 estados de data quality" || { echo "[FAIL] faltan los 5 estados GOOD/ACCEPTABLE/DEGRADED/INSUFFICIENT/INVALID"; FAIL=1; }
exit $FAIL
