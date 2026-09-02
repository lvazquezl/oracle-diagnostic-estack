#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
F="$ROOT/policies/capability-degradation-policy.md"
FAIL=0
grep -q '### `INSUFFICIENT_PRIVILEGES`' "$F" || { echo "[FAIL] falta estado INSUFFICIENT_PRIVILEGES"; FAIL=1; }
for field in capability_status reason impact alternative required_action; do
  grep -A12 '### `INSUFFICIENT_PRIVILEGES`' "$F" | grep -q "^$field:" || { echo "[FAIL] INSUFFICIENT_PRIVILEGES sin campo $field"; FAIL=1; }
done
[ $FAIL -eq 0 ] && echo "[PASS] INSUFFICIENT_PRIVILEGES documentado con los 5 campos obligatorios"
exit $FAIL
