#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 71/10 (# 394-406 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/normalization/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'INVALID_CAPACITY_INPUT' "$S" && echo "[PASS] declara INVALID_CAPACITY_INPUT cuando total_capacity <= 0" || { echo "[FAIL] falta INVALID_CAPACITY_INPUT"; FAIL=1; }
grep -q 'nunca se divide silenciosamente' "$S" && echo "[PASS] declara que nunca se divide silenciosamente" || { echo "[FAIL] falta la disciplina anti-división-silenciosa"; FAIL=1; }
exit $FAIL
