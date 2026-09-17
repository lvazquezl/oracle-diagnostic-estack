#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 81 (# 233-234 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
M="$ROOT/agents/capacity-analyst/manifest.yaml"

[ -f "$M" ] || { echo "[FAIL] falta $M"; exit 1; }
grep -q 'agregar disco a un diskgroup ASM' "$M" && echo "[PASS] declara la prohibición de agregar disco ASM" || { echo "[FAIL] falta la prohibición de agregar disco ASM"; FAIL=1; }
exit $FAIL
