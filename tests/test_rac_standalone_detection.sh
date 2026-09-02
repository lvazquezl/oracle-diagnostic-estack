#!/usr/bin/env bash
# Valida que el modelo de discovery distinga explícitamente RAC/standalone/RAC One Node.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
F="$ROOT/skills/core/context-discovery.md"

if grep -q 'instance_mode = rac' "$F" && grep -q 'single' "$F" && grep -qi 'rac_one_node\|RAC One Node' "$F"; then
  echo "[PASS] core/context-discovery distingue single/rac/rac_one_node"
else
  echo "[FAIL] core/context-discovery no distingue explícitamente single/rac/rac_one_node"
  FAIL=1
fi

if grep -q 'instance_mode = rac' "$ROOT/agents/oracle-discovery-analyst.md" 2>/dev/null || grep -qi 'instance_mode' "$ROOT/agents/oracle-discovery-analyst.md"; then
  echo "[PASS] oracle-discovery-analyst reporta instance_mode"
else
  echo "[FAIL] oracle-discovery-analyst no reporta instance_mode"
  FAIL=1
fi

exit $FAIL
