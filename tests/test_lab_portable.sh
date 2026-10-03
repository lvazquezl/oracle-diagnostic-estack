#!/usr/bin/env bash
# CHG-ESTACK-LAB-PORTABLE-001 — real lab adapter on Windows, Linux and macOS: filesec, oracle_wallet (thick + SEPS), keychain unchanged (no Oracle).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT
PYTHONDONTWRITEBYTECODE=1 python3 -m tests.p19.check_lab_portable 2>&1 | tee "$LOG" | grep --line-buffered -E '^\[(PASS|FAIL|SKIP)\]|checks OK|Error'
RC=${PIPESTATUS[0]}
if [ "$RC" -ne 0 ]; then
  tail -n 40 "$LOG"
  echo "[FAIL] check_lab_portable (exit $RC)"
  exit 1
fi
echo "[PASS] check_lab_portable"
exit 0
