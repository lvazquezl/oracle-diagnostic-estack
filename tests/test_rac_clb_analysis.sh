#!/usr/bin/env bash
# rac/clb distingue CLB de RLB explícitamente (# 16 — nunca tratarlos como equivalentes).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/rac/clb/SKILL.md"

grep -qi 'Distinto de RLB' "$S" && echo "[PASS] rac/clb distingue explícitamente CLB de RLB" || { echo "[FAIL] falta la distinción explícita"; FAIL=1; }
grep -q 'CLB_GOAL' "$S" && echo "[PASS] rac/clb usa CLB_GOAL" || { echo "[FAIL] falta CLB_GOAL"; FAIL=1; }

exit $FAIL
