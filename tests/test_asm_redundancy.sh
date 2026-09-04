#!/usr/bin/env bash
# asm/redundancy reconoce EXTERNAL/NORMAL/HIGH/FLEX/EXTENDED, usa metadata reportada (# 25).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/asm/redundancy/SKILL.md"

grep -q 'EXTERNAL|NORMAL|HIGH|FLEX|EXTENDED' "$S" && echo "[PASS] asm/redundancy reconoce los 5 niveles" || { echo "[FAIL] falta el enum completo"; FAIL=1; }
grep -qi 'nunca inferido de otra métrica' "$S" && echo "[PASS] usa metadata directa, nunca inferida" || { echo "[FAIL] falta la restricción"; FAIL=1; }

exit $FAIL
