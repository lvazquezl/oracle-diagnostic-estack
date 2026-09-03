#!/usr/bin/env bash
# Valida que la policy de costo defina LOW y que exista al menos una query certificada LOW.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

if grep -q '`LOW`' "$ROOT/policies/query-cost-policy.md"; then
  echo "[PASS] policies/query-cost-policy.md documenta la clase LOW"
else
  echo "[FAIL] policies/query-cost-policy.md no documenta la clase LOW"
  FAIL=1
fi

if grep -rq '^cost_class: LOW$' --include='Q-*.md' -R "$ROOT/queries"; then
  echo "[PASS] Existe al menos una query certificada con cost_class LOW"
else
  echo "[FAIL] Ninguna query certificada tiene cost_class LOW"
  FAIL=1
fi

exit $FAIL
