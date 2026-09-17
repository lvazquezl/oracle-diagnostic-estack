#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 83/68 (# 1527-1539 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/forecasting/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'algorithm_version: string' "$S" && echo "[PASS] el forecast registra algorithm_version" || { echo "[FAIL] falta algorithm_version"; FAIL=1; }
exit $FAIL
