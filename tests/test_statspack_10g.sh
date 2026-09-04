#!/usr/bin/env bash
# Valida que Q-PERF-WAIT-STATSPACK-001 cubra 10g y que la fixture 10g-statspack.yaml exista.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
F="$ROOT/queries/performance/waits/Q-PERF-WAIT-STATSPACK-001.md"

grep -q '10g' "$F" && echo "[PASS] Q-PERF-WAIT-STATSPACK-001 cubre 10g" || { echo "[FAIL] no cubre 10g"; FAIL=1; }
[ -f "$ROOT/tests/fixtures/10g-statspack.yaml" ] && echo "[PASS] fixture 10g-statspack.yaml existe" || { echo "[FAIL] falta fixture 10g-statspack.yaml"; FAIL=1; }

exit $FAIL
