#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 81 (# 232 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
M="$ROOT/agents/capacity-analyst/manifest.yaml"

[ -f "$M" ] || { echo "[FAIL] falta $M"; exit 1; }
grep -q 'extender filesystem/volumen' "$M" && echo "[PASS] declara la prohibición de extender filesystem/volumen" || { echo "[FAIL] falta la prohibición de extender filesystem"; FAIL=1; }
exit $FAIL
