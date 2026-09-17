#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 74/47 (# 1078-1088 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/memory/SKILL.md"
T="$ROOT/skills/capacity/threshold-crossing/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$T" ] || { echo "[FAIL] falta $T"; exit 1; }
grep -q 'memory-forecast-semantics' "$S" && echo "[PASS] referencia el modelo de forecast de memoria" || { echo "[FAIL] falta la referencia a memory-forecast-semantics"; FAIL=1; }
grep -q 'Memory forecast semantics' "$T" && echo "[PASS] threshold-crossing declara Memory forecast semantics" || { echo "[FAIL] falta la sección Memory forecast semantics"; FAIL=1; }
exit $FAIL
