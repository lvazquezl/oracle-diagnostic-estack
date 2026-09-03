#!/usr/bin/env bash
# Valida el caso 11g Standalone: fixture existe, SPFILE awareness cubre el caso "sin SPFILE".
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
FX="$ROOT/tests/fixtures/11g-standalone.yaml"

[ -f "$FX" ] || { echo "[FAIL] falta fixture 11g-standalone.yaml"; FAIL=1; }
grep -q 'major: 11' "$FX" 2>/dev/null && echo "[PASS] fixture declara oracle_version.major=11" || { echo "[FAIL] fixture no declara major=11"; FAIL=1; }
grep -q 'spfile_params_count: 0' "$FX" 2>/dev/null && echo "[PASS] fixture ejercita el caso sin SPFILE" || { echo "[FAIL] fixture no ejercita el caso sin SPFILE"; FAIL=1; }

if [ -f "$ROOT/skills/oracle/spfile/SKILL.md" ] && grep -q 'no existe SPFILE' "$ROOT/skills/oracle/spfile/SKILL.md"; then
  echo "[PASS] skills/oracle/spfile documenta el caso sin SPFILE"
else
  echo "[FAIL] skills/oracle/spfile no documenta el caso sin SPFILE"
  FAIL=1
fi

exit $FAIL
