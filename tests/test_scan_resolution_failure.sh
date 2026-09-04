#!/usr/bin/env bash
# El fixture 19c-scan-dns-failure declara SERVFAIL y clasificación NAME_RESOLUTION esperada.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
FX="$ROOT/tests/fixtures/19c-scan-dns-failure.yaml"

[ -f "$FX" ] || { echo "[FAIL] falta fixture 19c-scan-dns-failure.yaml"; exit 1; }
grep -q 'resolution_status: SERVFAIL' "$FX" && echo "[PASS] fixture declara SERVFAIL" || { echo "[FAIL] falta SERVFAIL"; FAIL=1; }
grep -q 'NAME_RESOLUTION' "$FX" && echo "[PASS] fixture espera clasificación NAME_RESOLUTION" || { echo "[FAIL] falta la clasificación esperada"; FAIL=1; }

exit $FAIL
