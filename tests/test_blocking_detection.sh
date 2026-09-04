#!/usr/bin/env bash
# Valida que Q-PERF-BLOCKING-001 use V$SESSION.BLOCKING_SESSION y que la fixture 19c-blocking.yaml exista.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
F="$ROOT/queries/performance/concurrency/Q-PERF-BLOCKING-001.md"

[ -f "$F" ] || { echo "[FAIL] falta Q-PERF-BLOCKING-001.md"; exit 1; }
grep -qi 'blocking_session' "$F" && echo "[PASS] usa blocking_session" || { echo "[FAIL] no usa blocking_session"; FAIL=1; }
[ -f "$ROOT/tests/fixtures/19c-blocking.yaml" ] && echo "[PASS] fixture 19c-blocking.yaml existe" || { echo "[FAIL] falta fixture 19c-blocking.yaml"; FAIL=1; }

exit $FAIL
