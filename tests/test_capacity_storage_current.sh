#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 75/13 (# 446-459 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/storage/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'storage_capacity:' "$S" && echo "[PASS] declara el esquema storage_capacity" || { echo "[FAIL] falta storage_capacity:"; FAIL=1; }
grep -q 'physical_datastore|volume_filesystem_asm|database_logical|tablespace_datafile' "$S" && echo "[PASS] declara las 4 capas del storage layer model" || { echo "[FAIL] faltan las capas de storage"; FAIL=1; }
exit $FAIL
