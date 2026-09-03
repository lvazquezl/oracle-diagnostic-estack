#!/usr/bin/env bash
# Valida el caso 10g Standalone NON-CDB: la fixture existe, container_mode se determina sin
# depender de V$DATABASE.CDB (columna inexistente en 10g).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
FX="$ROOT/tests/fixtures/10g-standalone-noncdb.yaml"

[ -f "$FX" ] || { echo "[FAIL] falta fixture 10g-standalone-noncdb.yaml"; FAIL=1; }
grep -q 'major: 10' "$FX" 2>/dev/null && echo "[PASS] fixture declara oracle_version.major=10" || { echo "[FAIL] fixture no declara major=10"; FAIL=1; }
grep -q 'multitenant_mode: non_cdb' "$FX" 2>/dev/null && echo "[PASS] fixture declara multitenant_mode=non_cdb" || { echo "[FAIL] fixture no declara non_cdb"; FAIL=1; }

AGENT="$ROOT/agents/oracle-discovery-analyst/AGENT.md"
if grep -q 'V\$DATABASE.CDB.*no existe\|en 10g.*non_cdb' "$AGENT"; then
  echo "[PASS] oracle-discovery-analyst declara que CDB no existe en 10g sin leer la columna"
else
  echo "[FAIL] oracle-discovery-analyst no documenta el caso 10g sin columna CDB"
  FAIL=1
fi

exit $FAIL
