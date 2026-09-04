#!/usr/bin/env bash
# asm/rebalance extrae operation/state/power/actual/sofar/est_work/est_rate/est_minutes (# 27).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/asm/rebalance/SKILL.md"

for field in operation state power actual sofar est_work est_rate est_minutes; do
  grep -q "$field" "$S" && echo "[PASS] asm/rebalance extrae $field" || { echo "[FAIL] falta $field"; FAIL=1; }
done

exit $FAIL
