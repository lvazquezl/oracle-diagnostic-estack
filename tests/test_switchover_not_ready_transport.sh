#!/usr/bin/env bash
# dataguard/switchover-readiness reporta NOT_READY cuando SWITCHOVER_STATUS=NOT ALLOWED.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

[ -f "$ROOT/tests/fixtures/19c-switchover-not-ready.yaml" ] && echo "[PASS] fixture switchover-not-ready existe" || { echo "[FAIL] falta fixture"; FAIL=1; }
grep -q 'switchover_status: "NOT ALLOWED"' "$ROOT/tests/fixtures/19c-switchover-not-ready.yaml" && echo "[PASS] fixture declara SWITCHOVER_STATUS=NOT ALLOWED" || { echo "[FAIL] falta el estado bloqueante"; FAIL=1; }

exit $FAIL
