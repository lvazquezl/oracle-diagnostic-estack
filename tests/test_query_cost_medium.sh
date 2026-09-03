#!/usr/bin/env bash
# Valida que la policy de costo defina MEDIUM y que exista al menos una query certificada MEDIUM
# con ventana de tiempo obligatoria documentada.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

if grep -q '`MEDIUM`' "$ROOT/policies/query-cost-policy.md"; then
  echo "[PASS] policies/query-cost-policy.md documenta la clase MEDIUM"
else
  echo "[FAIL] policies/query-cost-policy.md no documenta la clase MEDIUM"
  FAIL=1
fi

if grep -rq '^cost_class: MEDIUM$' --include='Q-*.md' -R "$ROOT/queries"; then
  echo "[PASS] Existe al menos una query certificada con cost_class MEDIUM"
else
  echo "[FAIL] Ninguna query certificada tiene cost_class MEDIUM"
  FAIL=1
fi

exit $FAIL
