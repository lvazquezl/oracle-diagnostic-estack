#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 79/54 (# 1208-1220 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
TP="$ROOT/docs/TARGET_PROFILE.md"

[ -f "$TP" ] || { echo "[FAIL] falta $TP"; exit 1; }
grep -q 'source_priority:' "$TP" && echo "[PASS] Target Profile declara capacity.source_priority" || { echo "[FAIL] falta source_priority en TARGET_PROFILE.md"; FAIL=1; }
exit $FAIL
