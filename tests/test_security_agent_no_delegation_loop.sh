#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 2.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
COLLAB="$ROOT/agents/oracle-security-analyst/collaboration.yaml"

grep -q "no_delegation_loop_rule:" "$COLLAB" && echo "[PASS] declara no_delegation_loop_rule" || { echo "[FAIL] falta no_delegation_loop_rule"; FAIL=1; }
grep -q "must_not_delegate_to: \[oracle-dba-analyst, oracle-discovery-analyst\]" "$COLLAB" \
  && echo "[PASS] must_not_delegate_to correcto" || { echo "[FAIL] falta must_not_delegate_to correcto"; FAIL=1; }

# oracle-security-analyst no debe aparecer en su propia may_delegate_to (loop trivial).
grep "may_delegate_to:" "$COLLAB" | grep -q "oracle-security-analyst" \
  && { echo "[FAIL] may_delegate_to se referencia a sí mismo"; FAIL=1; } \
  || echo "[PASS] may_delegate_to no se referencia a sí mismo"

exit $FAIL
