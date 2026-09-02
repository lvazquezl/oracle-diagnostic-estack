#!/usr/bin/env bash
# Valida que la Capability Matrix marque Multitenant como UNSUPPORTED en 10g/11g (la feature no existe).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

if grep -A4 'id: multitenant' "$ROOT/config/capability-matrix.yaml" | grep -q '10g: UNSUPPORTED'; then
  echo "[PASS] config/capability-matrix.yaml marca multitenant 10g como UNSUPPORTED"
else
  echo "[FAIL] config/capability-matrix.yaml no marca multitenant 10g como UNSUPPORTED"
  FAIL=1
fi

if grep -Eq '\| Multitenant \| UNSUPPORTED \| UNSUPPORTED' "$ROOT/docs/CAPABILITY_MATRIX.md"; then
  echo "[PASS] docs/CAPABILITY_MATRIX.md marca Multitenant 10g/11g como UNSUPPORTED"
else
  echo "[FAIL] docs/CAPABILITY_MATRIX.md no marca Multitenant 10g/11g como UNSUPPORTED"
  FAIL=1
fi

if grep -q '10g          → multitenant/\*     → UNSUPPORTED' "$ROOT/policies/version-awareness-policy.md"; then
  echo "[PASS] policies/version-awareness-policy.md documenta el ejemplo 10g/multitenant -> UNSUPPORTED"
else
  echo "[FAIL] policies/version-awareness-policy.md no documenta el ejemplo 10g/multitenant -> UNSUPPORTED"
  FAIL=1
fi

exit $FAIL
