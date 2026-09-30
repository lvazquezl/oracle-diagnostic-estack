#!/usr/bin/env bash
# CHG-ESTACK-COLLECTOR-FACTORY-B1 — collector factory drift guard, generated specs, fixtures and lab minimization (no Oracle).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT
PYTHONDONTWRITEBYTECODE=1 python3 -m tests.p18.check_collector_factory 2>&1 | tee "$LOG" | grep --line-buffered -E '^\[(PASS|FAIL|SKIP)\]|checks OK|Error'
RC=${PIPESTATUS[0]}
if [ "$RC" -ne 0 ]; then
  tail -n 40 "$LOG"
  echo "[FAIL] check_collector_factory (exit $RC)"
  exit 1
fi
echo "[PASS] check_collector_factory"
exit 0
