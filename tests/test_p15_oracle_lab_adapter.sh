#!/usr/bin/env bash
# PHASE 15 (CHG-ESTACK-ORA19C-LAB-001) — LAB oracle_sql adapter: functional checks through the real gateway path
# with a FAKE python-oracledb driver and a FAKE Keychain runner (no Oracle, no network, no Keychain access).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT
PYTHONDONTWRITEBYTECODE=1 python3 -m tests.p15.check_lab_adapter 2>&1 | tee "$LOG" | grep --line-buffered -E '^\[(PASS|FAIL|SKIP)\]|checks OK|Error'
RC=${PIPESTATUS[0]}
if [ "$RC" -ne 0 ]; then
  tail -n 40 "$LOG"
  echo "[FAIL] check_lab_adapter (exit $RC)"
  exit 1
fi
echo "[PASS] check_lab_adapter"
exit 0
