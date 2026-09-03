#!/usr/bin/env bash
# Valida el caso 19c Physical Standby: fixture existe con open_mode=MOUNTED, no READ WRITE.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
FX="$ROOT/tests/fixtures/19c-physical-standby.yaml"

[ -f "$FX" ] || { echo "[FAIL] falta fixture 19c-physical-standby.yaml"; FAIL=1; }
grep -q 'database_role: physical_standby' "$FX" 2>/dev/null && echo "[PASS] fixture declara database_role=physical_standby" || { echo "[FAIL] fixture no declara physical_standby"; FAIL=1; }
grep -q 'open_mode: "MOUNTED"' "$FX" 2>/dev/null && echo "[PASS] fixture NO asume READ WRITE en standby" || { echo "[FAIL] fixture asume open_mode incorrecto para standby"; FAIL=1; }

if grep -qi 'nunca se asume.*READ WRITE\|nunca.*asume `READ WRITE`' "$ROOT/agents/oracle-discovery-analyst/AGENT.md"; then
  echo "[PASS] oracle-discovery-analyst declara explícitamente que nunca asume READ WRITE en standby"
else
  echo "[FAIL] oracle-discovery-analyst no declara la regla de no asumir READ WRITE"
  FAIL=1
fi

exit $FAIL
