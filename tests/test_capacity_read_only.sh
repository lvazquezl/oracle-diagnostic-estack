#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 81 (# 1717-1730 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
M="$ROOT/agents/capacity-analyst/manifest.yaml"

[ -f "$M" ] || { echo "[FAIL] falta $M"; exit 1; }
grep -q 'security_mode: READ_ONLY_ALWAYS' "$M" && echo "[PASS] capacity-analyst declara security_mode: READ_ONLY_ALWAYS" || { echo "[FAIL] falta security_mode: READ_ONLY_ALWAYS"; FAIL=1; }
exit $FAIL
