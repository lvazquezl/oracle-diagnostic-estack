#!/usr/bin/env bash
# dataguard/transport reconoce el estado HEALTHY (destino VALID sin error).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/dataguard/transport/SKILL.md"

grep -q 'HEALTHY' "$S" && echo "[PASS] transport reconoce HEALTHY" || { echo "[FAIL] falta HEALTHY"; FAIL=1; }
[ -f "$ROOT/tests/fixtures/19c-physical-standby-healthy.yaml" ] && echo "[PASS] fixture de baseline sano existe" || { echo "[FAIL] falta fixture"; FAIL=1; }

exit $FAIL
