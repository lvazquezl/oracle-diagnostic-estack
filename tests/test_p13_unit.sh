#!/usr/bin/env bash
# PHASE 13 — MCP DIAGNOSTIC GATEWAY & LOCAL INTEGRATION: unit tests: schema validator, sanitizer primitives, salted tokens, evidence store, adapter deadline, audit, fixed errors
# Functional test: runs tests/p13/check_unit.py against the real gateway with SYNTHETIC fixtures only (no Oracle, no
# network, no host access). Output is streamed live and kept in a bounded temp file removed on exit; a slow run
# is distinguishable from a hang. Opt-in diagnostics: P13_TIMING=1 prints `[TIME] <case> <seconds>`.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT
PYTHONDONTWRITEBYTECODE=1 python3 -m tests.p13.check_unit 2>&1 | tee "$LOG" | grep --line-buffered -E '^\[(PASS|FAIL|SKIP|TIME)\]|checks OK|MUTATION SURVIVED|Error'
RC=${PIPESTATUS[0]}
if [ "$RC" -ne 0 ]; then
  tail -n 40 "$LOG"
  echo "[FAIL] check_unit (exit $RC)"
  exit 1
fi
echo "[PASS] check_unit"
exit 0
