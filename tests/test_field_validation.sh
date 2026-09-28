#!/usr/bin/env bash
# CHG-ESTACK-VALIDATION-MATRIX-001 — field validation registry coherence and levels (synthetic targets, no Oracle).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT
PYTHONDONTWRITEBYTECODE=1 python3 -m tests.p16.check_field_validation 2>&1 | tee "$LOG" | grep --line-buffered -E '^\[(PASS|FAIL|SKIP)\]|checks OK|Error'
RC=${PIPESTATUS[0]}
if [ "$RC" -ne 0 ]; then
  tail -n 40 "$LOG"
  echo "[FAIL] check_field_validation (exit $RC)"
  exit 1
fi
echo "[PASS] check_field_validation"
exit 0
