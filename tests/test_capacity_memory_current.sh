#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 74/12 (# 428-443 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/memory/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'memory_capacity:' "$S" && echo "[PASS] declara el esquema memory_capacity" || { echo "[FAIL] falta memory_capacity:"; FAIL=1; }
grep -q 'physical_allocated: number|null' "$S" && echo "[PASS] declara physical/allocated memory" || { echo "[FAIL] falta physical_allocated"; FAIL=1; }
grep -q 'sga_pga_context' "$S" && echo "[PASS] declara contexto SGA/PGA" || { echo "[FAIL] falta sga_pga_context"; FAIL=1; }
exit $FAIL
