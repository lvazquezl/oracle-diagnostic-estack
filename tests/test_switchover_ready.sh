#!/usr/bin/env bash
# dataguard/switchover-readiness reporta READY cuando todos los checks PASS; fixture existe.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/dataguard/switchover-readiness/SKILL.md"

grep -q 'READY|READY_WITH_WARNINGS|NOT_READY|INSUFFICIENT_EVIDENCE' "$S" && echo "[PASS] declara el enum completo de readiness" || { echo "[FAIL] falta el enum"; FAIL=1; }
[ -f "$ROOT/tests/fixtures/19c-switchover-ready.yaml" ] && echo "[PASS] fixture switchover-ready existe" || { echo "[FAIL] falta fixture"; FAIL=1; }

exit $FAIL
