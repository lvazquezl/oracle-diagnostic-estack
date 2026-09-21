#!/usr/bin/env bash
# PHASE 14 — PRODUCTION READINESS, GOVERNANCE & E-STACK EVOLUTION: evidence verifier negative cases and the release readiness gate verdict/readiness derivation
# Functional test: runs tests/p14/check_gate.py against the real code with SYNTHETIC data only (no Oracle, no
# network, no host access). Output is streamed live and kept in a bounded temp file removed on exit; a slow run
# is distinguishable from a hang. Opt-in diagnostics: P14_TIMING=1 prints `[TIME] <case> <seconds>`.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT
PYTHONDONTWRITEBYTECODE=1 python3 -m tests.p14.check_gate 2>&1 | tee "$LOG" | grep --line-buffered -E '^\[(PASS|FAIL|SKIP|TIME)\]|checks OK|MUTATION SURVIVED|Error'
RC=${PIPESTATUS[0]}
if [ "$RC" -ne 0 ]; then
  tail -n 40 "$LOG"
  echo "[FAIL] check_gate (exit $RC)"
  exit 1
fi
echo "[PASS] check_gate"
exit 0
