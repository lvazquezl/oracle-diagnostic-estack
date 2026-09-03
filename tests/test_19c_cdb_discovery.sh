#!/usr/bin/env bash
# Valida el caso 19c Standalone CDB: fixture existe con RU derivado (19.21).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
FX="$ROOT/tests/fixtures/19c-standalone-cdb.yaml"

[ -f "$FX" ] || { echo "[FAIL] falta fixture 19c-standalone-cdb.yaml"; FAIL=1; }
grep -q 'major: 19' "$FX" 2>/dev/null && echo "[PASS] fixture declara oracle_version.major=19" || { echo "[FAIL] fixture no declara major=19"; FAIL=1; }
grep -q 'ru: "19.21"' "$FX" 2>/dev/null && echo "[PASS] fixture declara ru derivado" || { echo "[FAIL] fixture no declara ru"; FAIL=1; }

if grep -q 'ru.*Release Update\|Release Update.*19' "$ROOT/policies/version-awareness-policy.md"; then
  echo "[PASS] version-awareness-policy documenta el campo ru (Release Update)"
else
  echo "[FAIL] version-awareness-policy no documenta ru"
  FAIL=1
fi

exit $FAIL
