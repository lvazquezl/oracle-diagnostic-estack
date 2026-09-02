#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
F="$ROOT/policies/capability-degradation-policy.md"
FAIL=0
grep -q '### `POLICY_BLOCKED`' "$F" || { echo "[FAIL] falta estado POLICY_BLOCKED"; FAIL=1; }
for field in capability_status reason impact alternative required_action; do
  grep -A12 '### `POLICY_BLOCKED`' "$F" | grep -q "^$field:" || { echo "[FAIL] POLICY_BLOCKED sin campo $field"; FAIL=1; }
done
[ $FAIL -eq 0 ] && echo "[PASS] POLICY_BLOCKED documentado con los 5 campos obligatorios"
exit $FAIL
