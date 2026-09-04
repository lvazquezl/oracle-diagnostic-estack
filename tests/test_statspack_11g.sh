#!/usr/bin/env bash
# Valida que Q-PERF-WAIT-STATSPACK-001 cubra 11g y que la fixture 11g-statspack.yaml exista.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
F="$ROOT/queries/performance/waits/Q-PERF-WAIT-STATSPACK-001.md"

grep -q '11g' "$F" && echo "[PASS] Q-PERF-WAIT-STATSPACK-001 cubre 11g" || { echo "[FAIL] no cubre 11g"; FAIL=1; }
[ -f "$ROOT/tests/fixtures/11g-statspack.yaml" ] && echo "[PASS] fixture 11g-statspack.yaml existe" || { echo "[FAIL] falta fixture 11g-statspack.yaml"; FAIL=1; }

exit $FAIL
