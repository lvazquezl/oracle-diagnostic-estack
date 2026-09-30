#!/usr/bin/env bash
# CHG-ESTACK-HUMAN-EVIDENCE-001 — human-reported evidence request/ingest and local sanitization (synthetic CSVs, no Oracle).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT
PYTHONDONTWRITEBYTECODE=1 python3 -m tests.p17.check_human_evidence 2>&1 | tee "$LOG" | grep --line-buffered -E '^\[(PASS|FAIL|SKIP)\]|checks OK|Error'
RC=${PIPESTATUS[0]}
if [ "$RC" -ne 0 ]; then
  tail -n 40 "$LOG"
  echo "[FAIL] check_human_evidence (exit $RC)"
  exit 1
fi
echo "[PASS] check_human_evidence"
exit 0
