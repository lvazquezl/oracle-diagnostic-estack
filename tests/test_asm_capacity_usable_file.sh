#!/usr/bin/env bash
# asm/capacity usa USABLE_FILE_MB/REQUIRED_MIRROR_FREE_MB, nunca FREE_MB aislado (# 24, # 54).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/asm/capacity/SKILL.md"

for field in USABLE_FILE_MB REQUIRED_MIRROR_FREE_MB REDUNDANCY; do
  grep -q "$field" "$S" && echo "[PASS] asm/capacity usa $field" || { echo "[FAIL] falta $field"; FAIL=1; }
done
grep -qi 'nunca en .FREE_MB. aislado' "$S" && echo "[PASS] prohibición explícita de FREE_MB aislado" || { echo "[FAIL] falta la prohibición"; FAIL=1; }

exit $FAIL
