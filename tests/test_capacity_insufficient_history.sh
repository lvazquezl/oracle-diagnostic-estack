#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 72/25 (# 671-692 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/data-quality/SKILL.md"
FX="$ROOT/tests/fixtures/capacity-insufficient-history-memory.yaml"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta fixture $FX"; exit 1; }
grep -q 'capacity.forecasting.minimum_samples' "$S" && echo "[PASS] referencia capacity.forecasting.minimum_samples" || { echo "[FAIL] falta la referencia a minimum_samples"; FAIL=1; }
grep -q 'confidence: INSUFFICIENT' "$FX" && echo "[PASS] fixture declara confidence: INSUFFICIENT" || { echo "[FAIL] fixture no declara INSUFFICIENT"; FAIL=1; }
exit $FAIL
