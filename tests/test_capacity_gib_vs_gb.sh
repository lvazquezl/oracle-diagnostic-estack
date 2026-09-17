#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 71/9 (# 370-377 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/normalization/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'GB decimal con GiB' "$S" && echo "[PASS] declara la disciplina anti-mezcla GB decimal / GiB binario" || { echo "[FAIL] falta la disciplina GB decimal/GiB"; FAIL=1; }
exit $FAIL
