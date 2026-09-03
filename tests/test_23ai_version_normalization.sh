#!/usr/bin/env bash
# Valida que 23ai se normalice como tupla (major, minor), no como comparación de strings.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
FX="$ROOT/tests/fixtures/23ai-standalone-cdb.yaml"

[ -f "$FX" ] || { echo "[FAIL] falta fixture 23ai-standalone-cdb.yaml"; FAIL=1; }
grep -q 'major: 23' "$FX" 2>/dev/null && echo "[PASS] fixture declara oracle_version.major=23" || { echo "[FAIL] fixture no declara major=23"; FAIL=1; }
grep -q 'normalization_assertions' "$FX" 2>/dev/null && echo "[PASS] fixture incluye assertions de normalización" || { echo "[FAIL] fixture no incluye assertions"; FAIL=1; }

if grep -qi 'ninguna capability compara versiones oracle como strings' "$ROOT/policies/version-awareness-policy.md"; then
  echo "[PASS] version-awareness-policy prohíbe explícitamente comparación de versión como string"
else
  echo "[FAIL] version-awareness-policy no prohíbe explícitamente comparación como string"
  FAIL=1
fi

exit $FAIL
