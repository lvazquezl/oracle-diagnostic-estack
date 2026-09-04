#!/usr/bin/env bash
# Valida routing.yaml/collaboration.yaml de oracle-rac-analyst.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
R="$ROOT/agents/oracle-rac-analyst/routing.yaml"

for field in activation_conditions deactivation_rule delegates_to receives_from must_not_delegate_to; do
  grep -qE "^${field}:" "$R" && echo "[PASS] routing.yaml declara $field" || { echo "[FAIL] falta $field"; FAIL=1; }
done

exit $FAIL
