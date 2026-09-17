#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 81 (# 240 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
M="$ROOT/agents/capacity-analyst/manifest.yaml"

[ -f "$M" ] || { echo "[FAIL] falta $M"; exit 1; }
grep -q 'modificar/reconfigurar herramientas de monitoreo' "$M" && echo "[PASS] declara la prohibición de modificar herramientas de monitoreo" || { echo "[FAIL] falta la prohibición de mutación de monitoreo"; FAIL=1; }
exit $FAIL
