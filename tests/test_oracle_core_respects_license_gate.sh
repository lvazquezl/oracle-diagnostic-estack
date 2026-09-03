#!/usr/bin/env bash
# Valida que las queries Oracle Core NO dependan de Diagnostics/Tuning Pack (AWR/ASH/ADDM/SQL
# Tuning Advisor quedan fuera de Fase 2 por diseño, sección 18).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in $(find "$ROOT/queries/oracle" -name 'Q-*.md'); do
  line=$(grep '^license_requirements:' "$f" || true)
  if ! echo "$line" | grep -q 'none'; then
    echo "[FAIL] $f declara license_requirements distinto de 'none' — Oracle Core (Fase 2) no debe depender de packs opcionales"
    FAIL=1
  fi
done
[ $FAIL -eq 0 ] && echo "[PASS] Ninguna query Oracle Core depende de licenciamiento adicional (AWR/ASH/ADDM quedan fuera de Fase 2)"

if grep -qi 'AWR' "$ROOT/agents/oracle-dba-analyst/AGENT.md" | grep -qi 'Fase 3'; then :; fi
if grep -q 'AWR/ASH/ADDM/SQL tuning' "$ROOT/agents/oracle-dba-analyst/AGENT.md" 2>/dev/null || grep -qi 'No hace deep-dive de performance (AWR/ASH/ADDM/SQL tuning)' "$ROOT/agents/oracle-dba-analyst/AGENT.md"; then
  echo "[PASS] oracle-dba-analyst declara explícitamente que AWR/ASH/ADDM/SQL tuning quedan fuera de Fase 2"
else
  echo "[FAIL] oracle-dba-analyst no excluye explícitamente AWR/ASH/ADDM/SQL tuning de Fase 2"
  FAIL=1
fi

exit $FAIL
