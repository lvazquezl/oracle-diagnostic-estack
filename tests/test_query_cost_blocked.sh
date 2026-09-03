#!/usr/bin/env bash
# Valida que la policy de costo defina BLOCKED como clase de rechazo, y que NINGUNA query
# certificada tenga cost_class BLOCKED (BLOCKED = nunca certificada, no un modo de ejecución).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

if grep -q '`BLOCKED`' "$ROOT/policies/query-cost-policy.md"; then
  echo "[PASS] policies/query-cost-policy.md documenta la clase BLOCKED"
else
  echo "[FAIL] policies/query-cost-policy.md no documenta la clase BLOCKED"
  FAIL=1
fi

if grep -rq '^cost_class: BLOCKED$' --include='Q-*.md' -R "$ROOT/queries"; then
  echo "[FAIL] Hay una query certificada con cost_class BLOCKED — contradictorio, no debería estar en el catálogo"
  FAIL=1
else
  echo "[PASS] Ninguna query certificada tiene cost_class BLOCKED"
fi

exit $FAIL
