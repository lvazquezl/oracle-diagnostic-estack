#!/usr/bin/env bash
# asm/disks cubre MOUNT_STATUS/HEADER_STATUS/MODE_STATUS/STATE/FAILGROUP/PATH/READ_ERRS/WRITE_ERRS,
# PATH siempre tokenizado (# 26).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/asm/disks/SKILL.md"
Q="$ROOT/queries/asm/Q-ASM-DISKS-001.md"

for field in MOUNT_STATUS HEADER_STATUS MODE_STATUS READ_ERRS WRITE_ERRS; do
  grep -q "$field" "$S" && echo "[PASS] asm/disks cubre $field" || { echo "[FAIL] falta $field"; FAIL=1; }
done
grep -qi 'PATH.*tokenizado' "$Q" && echo "[PASS] PATH tokenizado en sanitization notes" || { echo "[FAIL] falta tokenización de PATH"; FAIL=1; }

exit $FAIL
