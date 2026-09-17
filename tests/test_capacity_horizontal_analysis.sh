#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 80/22 (# 610-625 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/horizontal/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'horizontal_analysis:' "$S" && echo "[PASS] declara el esquema horizontal_analysis" || { echo "[FAIL] falta horizontal_analysis:"; FAIL=1; }
grep -q 'add nodes' "$S" && echo "[PASS] cubre add nodes/VMs/instances/storage devices" || { echo "[FAIL] falta add nodes"; FAIL=1; }
exit $FAIL
