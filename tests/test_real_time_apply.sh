#!/usr/bin/env bash
# dataguard/real-time-apply distingue archived-log apply de real-time apply (# 19).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/dataguard/real-time-apply/SKILL.md"

grep -q 'MANAGED REAL TIME APPLY' "$S" && echo "[PASS] distingue real-time apply por RECOVERY_MODE" || { echo "[FAIL] falta la distinción"; FAIL=1; }
grep -qi 'nunca asume que una standby está defectuosa' "$S" && echo "[PASS] no asume defecto sin requisito de diseño" || { echo "[FAIL] falta la regla # 19"; FAIL=1; }

exit $FAIL
