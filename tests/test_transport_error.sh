#!/usr/bin/env bash
# dataguard/transport clasifica ERROR/DESTINATION_UNAVAILABLE; fixture de destino en error existe.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/dataguard/transport/SKILL.md"

grep -q 'DESTINATION_UNAVAILABLE' "$S" && echo "[PASS] transport reconoce DESTINATION_UNAVAILABLE" || { echo "[FAIL] falta clasificación"; FAIL=1; }
[ -f "$ROOT/tests/fixtures/19c-destination-error.yaml" ] && echo "[PASS] fixture de destino en error existe" || { echo "[FAIL] falta fixture"; FAIL=1; }

exit $FAIL
