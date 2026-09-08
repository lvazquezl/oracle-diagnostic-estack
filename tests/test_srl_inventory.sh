#!/usr/bin/env bash
# dataguard/standby-redo-logs inventaria grupos/tamaño por thread.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/dataguard/standby-redo-logs/SKILL.md"

grep -q 'group_count' "$S" && grep -q 'size_mb' "$S" && echo "[PASS] SRL declara group_count/size_mb" || { echo "[FAIL] falta group_count/size_mb"; FAIL=1; }

exit $FAIL
