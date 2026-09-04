#!/usr/bin/env bash
# V$ASM_DISKGROUP (disk discovery) queda restringida a escenarios explícitos, nunca default (# 23).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/asm/diskgroups/SKILL.md"

grep -qi 'V\$ASM_DISKGROUP.*sólo se usa si disk discovery es explícitamente requerido' "$S" \
  && echo "[PASS] asm/diskgroups documenta la restricción explícita" \
  || { echo "[FAIL] falta la restricción explícita de V\$ASM_DISKGROUP"; FAIL=1; }

exit $FAIL
