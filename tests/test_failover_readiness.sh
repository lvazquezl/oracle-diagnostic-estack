#!/usr/bin/env bash
# dataguard/failover-readiness diferenciado explícitamente de switchover-readiness (# 31).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/dataguard/failover-readiness/SKILL.md"

grep -qi 'Diferenciado explícitamente de .dataguard/switchover-readiness' "$S" && echo "[PASS] failover-readiness se diferencia explícitamente" || { echo "[FAIL] falta la diferenciación"; FAIL=1; }
grep -q 'No presentar READY sin evidencia suficiente' "$S" && echo "[PASS] nunca READY sin evidencia (# 30)" || { echo "[FAIL] falta la regla # 30"; FAIL=1; }

exit $FAIL
