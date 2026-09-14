#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 2.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
R="$ROOT/agents/oracle-security-analyst/routing.yaml"

for field in activation_conditions deactivation_rule delegates_to receives_from must_not_delegate_to loop_prevention_rule; do
  grep -qE "^${field}:" "$R" && echo "[PASS] routing.yaml declara $field" || { echo "[FAIL] routing.yaml no declara $field"; FAIL=1; }
done

grep -q "oracle-dba-analyst, oracle-discovery-analyst\]" "$R" \
  && echo "[PASS] must_not_delegate_to incluye oracle-dba-analyst/oracle-discovery-analyst" \
  || { echo "[FAIL] falta must_not_delegate_to correcto"; FAIL=1; }

exit $FAIL
