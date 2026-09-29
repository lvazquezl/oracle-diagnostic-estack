#!/usr/bin/env bash
# V$ASM_DISKGROUP_STAT es la fuente por defecto para monitoreo rutinario ASM (# 23).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/asm/Q-ASM-TOPOLOGY-001.md"

block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$Q")
grep -qi 'v\$asm_diskgroup_stat' <<<"$block" && echo "[PASS] Q-ASM-TOPOLOGY-001 usa V\$ASM_DISKGROUP_STAT" || { echo "[FAIL] no usa V\$ASM_DISKGROUP_STAT"; FAIL=1; }
grep -qi '\bv\$asm_diskgroup\b' <<<"$block" && { echo "[FAIL] Q-ASM-TOPOLOGY-001 usa V\$ASM_DISKGROUP (costoso) en el SELECT base"; FAIL=1; } || echo "[PASS] no usa V\$ASM_DISKGROUP en el SELECT base"

exit $FAIL
