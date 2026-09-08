#!/usr/bin/env bash
# Valida que el modelo de discovery distinga explícitamente Primary/Physical Standby.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
F="$ROOT/skills/core/context-discovery.md"

if grep -qi 'database_role' "$F" && grep -qi 'primary' "$F" && grep -qi 'physical_standby' "$F"; then
  echo "[PASS] core/context-discovery distingue primary/physical_standby"
else
  echo "[FAIL] core/context-discovery no distingue explícitamente primary/physical_standby"
  FAIL=1
fi

if [ -f "$ROOT/skills/dataguard/lag/SKILL.md" ] && grep -q 'status: active' "$ROOT/skills/dataguard/lag/SKILL.md"; then
  echo "[PASS] skills/dataguard/lag/SKILL.md materializado y activo"
else
  echo "[FAIL] skills/dataguard/lag/SKILL.md ausente o no activo"
  FAIL=1
fi

exit $FAIL
