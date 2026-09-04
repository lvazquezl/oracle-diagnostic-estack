#!/usr/bin/env bash
# Nunca cambia POWER — ningún artefacto ASM declara ALTER DISKGROUP REBALANCE ejecutable.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in $(find "$ROOT/queries/asm" -name 'Q-*.md' 2>/dev/null); do
  block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$f")
  if echo "$block" | grep -Eiq 'ALTER DISKGROUP|REBALANCE POWER'; then
    echo "[FAIL] $f contiene ALTER DISKGROUP/REBALANCE ejecutable"
    FAIL=1
  fi
done

grep -qi 'Nunca cambia .POWER.' "$ROOT/skills/asm/rebalance/SKILL.md" && echo "[PASS] asm/rebalance prohíbe explícitamente cambiar POWER" || { echo "[FAIL] falta prohibición"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Ninguna query ASM ejecuta rebalance/ALTER DISKGROUP"
exit $FAIL
