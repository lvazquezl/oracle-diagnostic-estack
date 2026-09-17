#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 78/44 (# 1018-1035 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/threshold-crossing/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'INSUFFICIENT_EVIDENCE' "$S" && echo "[PASS] declara el estado INSUFFICIENT_EVIDENCE" || { echo "[FAIL] falta INSUFFICIENT_EVIDENCE"; FAIL=1; }
grep -q 'confidence del forecast es' "$S" && echo "[PASS] INSUFFICIENT_EVIDENCE se basa en confidence INSUFFICIENT del forecast" || { echo "[FAIL] falta la condición basada en confidence"; FAIL=1; }
exit $FAIL
