#!/usr/bin/env bash
# asm/healthcheck orquesta topology/capacity/redundancy/disks/rebalance (# 40).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/asm/healthcheck/SKILL.md"

for skill in "asm/diskgroups" "asm/capacity" "asm/redundancy" "asm/disks" "asm/rebalance"; do
  grep -q "$skill" "$S" && echo "[PASS] asm/healthcheck orquesta $skill" || { echo "[FAIL] falta $skill"; FAIL=1; }
done

exit $FAIL
