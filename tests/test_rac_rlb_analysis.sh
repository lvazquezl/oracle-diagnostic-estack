#!/usr/bin/env bash
# rac/rlb distingue RLB de CLB explícitamente y menciona FAN/FCF como requisito de efecto real.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/rac/rlb/SKILL.md"

grep -qi 'Distinto de CLB' "$S" && echo "[PASS] rac/rlb distingue explícitamente RLB de CLB" || { echo "[FAIL] falta la distinción explícita"; FAIL=1; }
grep -qi 'FAN/FCF' "$S" && echo "[PASS] rac/rlb menciona FAN/FCF como requisito de efecto" || { echo "[FAIL] falta la mención de FAN/FCF"; FAIL=1; }

exit $FAIL
