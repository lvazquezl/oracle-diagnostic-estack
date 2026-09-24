#!/usr/bin/env bash
# Valida que routing.yaml/collaboration.yaml no permitan un ciclo de delegación para
# oracle-multitenant-analyst. Mismo patrón dual-formato que test_dataguard_agent_no_delegation_loop.sh.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
R="$ROOT/agents/oracle-multitenant-analyst/routing.yaml"
C="$ROOT/agents/oracle-multitenant-analyst/collaboration.yaml"

extract_list() {
  local file="$1" key="$2"
  local inline
  inline=$(grep -E "^${key}:[[:space:]]*\[" "$file" | head -1)
  if [ -n "$inline" ]; then
    echo "$inline" | sed -E "s/^${key}:[[:space:]]*\[//; s/\][[:space:]]*$//" | tr ',' '\n' | sed -E 's/^[[:space:]]+|[[:space:]]+$//g' | grep -v '^$'
    return
  fi
  awk "/^${key}:/{f=1;next} /^[a-zA-Z_]+:/{f=0} f" "$file" \
    | grep -E '^[[:space:]]*-[[:space:]]' \
    | sed -E 's/^[[:space:]]*-[[:space:]]*//; s/[[:space:]]*#.*$//' \
    | grep -v '^$'
}

forbidden=$(extract_list "$R" "must_not_delegate_to")
delegated=$(awk '/^delegates_to:/{f=1;next} /^[a-zA-Z_]+:/{f=0} f' "$R" \
  | grep -oE 'agent:[[:space:]]*[a-z0-9-]+' | sed -E 's/agent:[[:space:]]*//')
may_delegate=$(extract_list "$C" "may_delegate_to")

[ -n "$forbidden" ] && echo "[PASS] must_not_delegate_to no está vacío: $forbidden" || { echo "[FAIL] must_not_delegate_to está vacío"; FAIL=1; }

for agent in $forbidden; do
  if echo "$delegated" | grep -qx "$agent"; then
    echo "[FAIL] $agent está en delegates_to pese a estar en must_not_delegate_to — ciclo posible"
    FAIL=1
  else
    echo "[PASS] $agent no está en delegates_to"
  fi
  if echo "$may_delegate" | grep -qx "$agent"; then
    echo "[FAIL] $agent está en may_delegate_to pese a estar en must_not_delegate_to"
    FAIL=1
  else
    echo "[PASS] $agent no está en may_delegate_to"
  fi
done

for must_forbid in oracle-dba-analyst oracle-discovery-analyst; do
  if echo "$forbidden" | grep -qx "$must_forbid"; then
    echo "[PASS] $must_forbid está en must_not_delegate_to"
  else
    echo "[FAIL] $must_forbid no está en must_not_delegate_to"
    FAIL=1
  fi
done

exit $FAIL
