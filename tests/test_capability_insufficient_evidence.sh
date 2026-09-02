#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
F="$ROOT/policies/capability-degradation-policy.md"
FAIL=0
grep -q '### `INSUFFICIENT_EVIDENCE`' "$F" || { echo "[FAIL] falta estado INSUFFICIENT_EVIDENCE"; FAIL=1; }
for field in capability_status reason impact alternative required_action; do
  grep -A12 '### `INSUFFICIENT_EVIDENCE`' "$F" | grep -q "^$field:" || { echo "[FAIL] INSUFFICIENT_EVIDENCE sin campo $field"; FAIL=1; }
done
[ $FAIL -eq 0 ] && echo "[PASS] INSUFFICIENT_EVIDENCE documentado con los 5 campos obligatorios"
exit $FAIL
