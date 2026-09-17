#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 72/26 (# 699-702 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/data-quality/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'duplicate samples' "$S" && echo "[PASS] evalúa duplicate samples" || { echo "[FAIL] falta duplicate samples"; FAIL=1; }
exit $FAIL
