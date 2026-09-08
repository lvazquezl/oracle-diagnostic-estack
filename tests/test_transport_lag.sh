#!/usr/bin/env bash
# dataguard/lag mide transport_lag por separado de apply_lag; fixture de transport lag existe.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/dataguard/lag/SKILL.md"

grep -q 'TRANSPORT_LAG' "$S" && echo "[PASS] lag declara TRANSPORT_LAG" || { echo "[FAIL] falta TRANSPORT_LAG"; FAIL=1; }
[ -f "$ROOT/tests/fixtures/19c-transport-lag.yaml" ] && echo "[PASS] fixture de transport lag existe" || { echo "[FAIL] falta fixture"; FAIL=1; }

exit $FAIL
