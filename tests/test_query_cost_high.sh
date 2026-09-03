#!/usr/bin/env bash
# Valida que la policy de costo defina HIGH con sus condiciones reforzadas, y que exista al menos
# una query certificada HIGH (ASH sobre ventana amplia).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

if grep -q '`HIGH`' "$ROOT/policies/query-cost-policy.md" && grep -qi 'time range' "$ROOT/policies/query-cost-policy.md"; then
  echo "[PASS] policies/query-cost-policy.md documenta la clase HIGH con condiciones reforzadas"
else
  echo "[FAIL] policies/query-cost-policy.md no documenta HIGH con condiciones reforzadas"
  FAIL=1
fi

if grep -rq '^cost_class: HIGH$' --include='Q-*.md' -R "$ROOT/queries"; then
  echo "[PASS] Existe al menos una query certificada con cost_class HIGH"
else
  echo "[FAIL] Ninguna query certificada tiene cost_class HIGH"
  FAIL=1
fi

exit $FAIL
