#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
F="$ROOT/policies/capability-degradation-policy.md"
FAIL=0
grep -q '### `LICENSE_RESTRICTED`' "$F" || { echo "[FAIL] falta estado LICENSE_RESTRICTED"; FAIL=1; }
for field in capability_status reason impact alternative required_action; do
  grep -A12 '### `LICENSE_RESTRICTED`' "$F" | grep -q "^$field:" || { echo "[FAIL] LICENSE_RESTRICTED sin campo $field"; FAIL=1; }
done
[ $FAIL -eq 0 ] && echo "[PASS] LICENSE_RESTRICTED documentado con los 5 campos obligatorios"
exit $FAIL
