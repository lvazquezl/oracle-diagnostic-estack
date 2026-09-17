#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 76/16 (# 501-519 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/asm/SKILL.md"
FX="$ROOT/tests/fixtures/capacity-asm-usable-file-mb.yaml"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta fixture $FX"; exit 1; }
grep -q 'USABLE_FILE_MB' "$S" && echo "[PASS] usa USABLE_FILE_MB como métrica de capacidad real" || { echo "[FAIL] falta USABLE_FILE_MB"; FAIL=1; }
grep -q 'FREE_MB / TOTAL_MB' "$S" && echo "[PASS] declara la disciplina anti-FREE_MB/TOTAL_MB simple" || { echo "[FAIL] falta la disciplina anti-FREE_MB/TOTAL_MB"; FAIL=1; }
grep -q 'usable_file_mb_used: true' "$FX" && echo "[PASS] fixture espera el uso de USABLE_FILE_MB" || { echo "[FAIL] fixture no espera USABLE_FILE_MB"; FAIL=1; }
exit $FAIL
