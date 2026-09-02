#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
F="$ROOT/policies/capability-degradation-policy.md"
FAIL=0
grep -q '### `ENVIRONMENT_UNKNOWN`' "$F" || { echo "[FAIL] falta estado ENVIRONMENT_UNKNOWN"; FAIL=1; }
for field in capability_status reason impact alternative required_action; do
  grep -A12 '### `ENVIRONMENT_UNKNOWN`' "$F" | grep -q "^$field:" || { echo "[FAIL] ENVIRONMENT_UNKNOWN sin campo $field"; FAIL=1; }
done
[ $FAIL -eq 0 ] && echo "[PASS] ENVIRONMENT_UNKNOWN documentado con los 5 campos obligatorios"
exit $FAIL
