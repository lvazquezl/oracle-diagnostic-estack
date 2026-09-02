#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
F="$ROOT/policies/capability-degradation-policy.md"
FAIL=0
grep -q '### `PARTIALLY_SUPPORTED`' "$F" || { echo "[FAIL] falta estado PARTIALLY_SUPPORTED"; FAIL=1; }
for field in capability_status reason impact alternative required_action; do
  grep -A12 '### `PARTIALLY_SUPPORTED`' "$F" | grep -q "^$field:" || { echo "[FAIL] PARTIALLY_SUPPORTED sin campo $field"; FAIL=1; }
done
[ $FAIL -eq 0 ] && echo "[PASS] PARTIALLY_SUPPORTED documentado con los 5 campos obligatorios"
exit $FAIL
