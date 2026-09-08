#!/usr/bin/env bash
# dataguard/switchover-readiness reporta READY_WITH_WARNINGS cuando no hay blocking pero sí warnings.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/dataguard/switchover-readiness/SKILL.md"

grep -q 'READY_WITH_WARNINGS' "$S" && echo "[PASS] declara READY_WITH_WARNINGS" || { echo "[FAIL] falta el estado"; FAIL=1; }
grep -qi 'sin .BLOCKING., con .WARNING.' "$S" && echo "[PASS] distingue warning de blocking" || { echo "[FAIL] falta la distinción"; FAIL=1; }

exit $FAIL
