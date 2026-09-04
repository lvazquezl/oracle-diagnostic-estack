#!/usr/bin/env bash
# Valida que ninguna query/skill de performance ejecute ALTER SYSTEM KILL SESSION — sólo
# texto de recomendación NOT_EXECUTED.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in $(find "$ROOT/queries/performance" -name 'Q-*.md'); do
  block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$f")
  if echo "$block" | grep -Eiq 'KILL SESSION|ALTER SYSTEM'; then
    echo "[FAIL] $f contiene KILL SESSION/ALTER SYSTEM ejecutable en su bloque SQL"
    FAIL=1
  fi
done

A="$ROOT/agents/oracle-performance-analyst/AGENT.md"
grep -qi 'no mata sesiones\|nunca.*KILL SESSION' "$A" && echo "[PASS] AGENT.md prohíbe explícitamente KILL SESSION" || { echo "[FAIL] AGENT.md no prohíbe KILL SESSION explícitamente"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Ninguna query de performance ejecuta KILL SESSION/ALTER SYSTEM"

exit $FAIL
