#!/usr/bin/env bash
# Valida que collaboration.yaml declare may_delegate_to/may_receive_from/must_not_delegate_to/
# escalation_conditions explícitos (# 30 COLLABORATION).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
C="$ROOT/agents/oracle-performance-analyst/collaboration.yaml"

[ -f "$C" ] || { echo "[FAIL] falta collaboration.yaml"; exit 1; }

for field in "^may_delegate_to:" "^may_receive_from:" "^must_not_delegate_to:" "^escalation_conditions:" "^manual_command_rule:"; do
  if grep -q "$field" "$C"; then
    echo "[PASS] collaboration.yaml declara $field"
  else
    echo "[FAIL] collaboration.yaml no declara $field"
    FAIL=1
  fi
done

exit $FAIL
