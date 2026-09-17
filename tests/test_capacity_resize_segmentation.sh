#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 75/51 (# 1155-1163 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/anomaly-awareness/SKILL.md"
FX="$ROOT/tests/fixtures/capacity-resize-event-storage.yaml"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta fixture $FX"; exit 1; }
grep -q 'Segmented forecast' "$S" && echo "[PASS] declara el modelo Segmented forecast" || { echo "[FAIL] falta Segmented forecast"; FAIL=1; }
grep -q 'capacity_resize' "$FX" && echo "[PASS] fixture modela un capacity_resize event" || { echo "[FAIL] fixture no declara capacity_resize"; FAIL=1; }
grep -q 'segmentation_applied: true' "$FX" && echo "[PASS] fixture espera segmentación aplicada" || { echo "[FAIL] fixture no espera segmentación"; FAIL=1; }
exit $FAIL
