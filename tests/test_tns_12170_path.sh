#!/usr/bin/env bash
# TNS-12170 documentado en knowledge base — dos escenarios distintos según resolución SCAN (# 51).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

KC="$ROOT/knowledge/errors/tns/TNS-12170-connect-timeout.md"
[ -f "$KC" ] && echo "[PASS] TNS-12170 knowledge entry existe" || { echo "[FAIL] falta la entrada de knowledge"; FAIL=1; }
grep -qi 'nunca afirma firewall como causa sin haber descartado' "$KC" \
  && echo "[PASS] TNS-12170 nunca afirma firewall sin descartar name-resolution/listener primero" \
  || { echo "[FAIL] falta la regla explícita"; FAIL=1; }

exit $FAIL
