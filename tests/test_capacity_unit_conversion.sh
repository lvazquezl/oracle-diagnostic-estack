#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 71/9 (# 358-377 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/normalization/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'cores/percentage' "$S" && echo "[PASS] normaliza CPU en cores/percentage" || { echo "[FAIL] falta cores/percentage"; FAIL=1; }
grep -q 'bytes/GiB' "$S" && echo "[PASS] normaliza Memory en bytes/GiB" || { echo "[FAIL] falta bytes/GiB"; FAIL=1; }
exit $FAIL
