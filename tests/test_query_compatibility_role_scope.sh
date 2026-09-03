#!/usr/bin/env bash
# Valida que las queries PRIMARY-only declaren database_role_scope: PRIMARY (nunca ANY), para que
# no se recomienden/ejecuten automáticamente sobre un standby.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for name in Q-ORA-REDO-001 Q-ORA-ARCHIVE-001 Q-ORA-UNDO-001 Q-ORA-JOBS-SUMMARY-001 Q-PERF-WAIT-AWR-001; do
  f=$(find "$ROOT/queries" -name "$name.md" 2>/dev/null)
  if [ -n "$f" ] && grep -q '^database_role_scope: PRIMARY$' "$f"; then
    echo "[PASS] $name declara database_role_scope: PRIMARY"
  else
    echo "[FAIL] $name no declara database_role_scope: PRIMARY"
    FAIL=1
  fi
done

if grep -qi 'no se puede asumir que una base standby.*READ WRITE\|nunca se asume.*READ WRITE' "$ROOT"/agents/oracle-discovery-analyst/AGENT.md "$ROOT"/skills/oracle/*/SKILL.md 2>/dev/null; then
  echo "[PASS] La regla 'nunca asumir READ WRITE en standby' está documentada"
else
  echo "[FAIL] La regla 'nunca asumir READ WRITE en standby' no está documentada explícitamente en ningún artefacto revisado"
  FAIL=1
fi

exit $FAIL
