#!/usr/bin/env bash
# Valida que exista una ruta alternativa no licenciada documentada cuando una capability es
# LICENSE_RESTRICTED (ej. AWR -> Statspack).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

if grep -qi 'Statspack' "$ROOT/policies/licensing-awareness-policy.md"; then
  echo "[PASS] licensing-awareness-policy.md documenta la alternativa no licenciada (Statspack) para AWR"
else
  echo "[FAIL] licensing-awareness-policy.md no documenta una alternativa no licenciada"
  FAIL=1
fi

if grep -qi 'Statspack' "$ROOT/skills/performance/wait-events/SKILL.md"; then
  echo "[PASS] skills/performance/wait-events/SKILL.md implementa el fallback AWR->Statspack"
else
  echo "[FAIL] skills/performance/wait-events/SKILL.md no implementa el fallback AWR->Statspack"
  FAIL=1
fi

if grep -q 'alternative' "$ROOT/policies/capability-degradation-policy.md"; then
  echo "[PASS] El estado LICENSE_RESTRICTED incluye campo 'alternative'"
else
  echo "[FAIL] LICENSE_RESTRICTED no incluye campo 'alternative'"
  FAIL=1
fi

exit $FAIL
