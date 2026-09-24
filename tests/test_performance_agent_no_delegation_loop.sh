#!/usr/bin/env bash
# Valida que routing.yaml/collaboration.yaml no permitan un ciclo de delegación: ningún agente
# listado en must_not_delegate_to aparece también como entrada real de delegates_to/
# may_delegate_to (# 30 COLLABORATION: "Evitar loops entre agentes").
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
R="$ROOT/agents/oracle-performance-analyst/routing.yaml"
C="$ROOT/agents/oracle-performance-analyst/collaboration.yaml"

# must_not_delegate_to entries are plain "- agent-name" list items (no "agent:" key) — extract
# just the first token after "- ", stripping any trailing inline comment.
forbidden=$(awk '/^must_not_delegate_to:/{f=1;next} /^[a-zA-Z_]+:/{f=0} f' "$R" \
  | grep -E '^[[:space:]]*-[[:space:]]' \
  | sed -E 's/^[[:space:]]*-[[:space:]]*//; s/[[:space:]]*#.*$//' \
  | grep -v '^$')

# delegates_to entries use "  - agent: <name>" — extract just the agent names in that section.
delegated=$(awk '/^delegates_to:/{f=1;next} /^[a-zA-Z_]+:/{f=0} f' "$R" \
  | grep -oE 'agent:[[:space:]]*[a-z0-9-]+' | sed -E 's/agent:[[:space:]]*//')

# may_delegate_to (collaboration.yaml) entries are plain "- agent-name" list items.
may_delegate=$(awk '/^may_delegate_to:/{f=1;next} /^[a-zA-Z_]+:/{f=0} f' "$C" \
  | grep -E '^[[:space:]]*-[[:space:]]' \
  | sed -E 's/^[[:space:]]*-[[:space:]]*//; s/[[:space:]]*#.*$//' \
  | grep -v '^$')

[ -n "$forbidden" ] && echo "[PASS] must_not_delegate_to no está vacío: $forbidden" || { echo "[FAIL] must_not_delegate_to está vacío"; FAIL=1; }

for agent in $forbidden; do
  if echo "$delegated" | grep -qx "$agent"; then
    echo "[FAIL] $agent está en delegates_to (routing.yaml) pese a estar en must_not_delegate_to — ciclo posible"
    FAIL=1
  else
    echo "[PASS] $agent no está en delegates_to"
  fi
  if echo "$may_delegate" | grep -qx "$agent"; then
    echo "[FAIL] $agent está en may_delegate_to (collaboration.yaml) pese a estar en must_not_delegate_to"
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
