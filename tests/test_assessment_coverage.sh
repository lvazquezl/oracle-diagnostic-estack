#!/usr/bin/env bash
# CHG-ESTACK-D-COMPLETE-WITHIN-POLICY-001 — domain coverage model, evaluator and assessment document (no Oracle).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT
PYTHONDONTWRITEBYTECODE=1 python3 -m tests.p20.check_assessment_coverage 2>&1 | tee "$LOG" | grep --line-buffered -E '^\[(PASS|FAIL|SKIP)\]|checks OK|Error'
RC=${PIPESTATUS[0]}
if [ "$RC" -ne 0 ]; then
  tail -n 40 "$LOG"
  echo "[FAIL] check_assessment_coverage (exit $RC)"
  exit 1
fi
echo "[PASS] check_assessment_coverage"
exit 0
