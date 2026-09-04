#!/usr/bin/env bash
# rac/healthcheck orquesta el flujo completo (# 39) y produce el Cluster Health Model (# 38).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/rac/healthcheck/SKILL.md"

for dim in NODE INSTANCE RESOURCE SERVICE NETWORK ASM; do
  grep -q "$dim" "$S" && echo "[PASS] rac/healthcheck cubre dimensión $dim" || { echo "[FAIL] falta dimensión $dim"; FAIL=1; }
done
grep -qi 'nunca un score opaco único' "$S" && echo "[PASS] no genera score opaco único" || { echo "[FAIL] falta la prohibición de score opaco"; FAIL=1; }

exit $FAIL
