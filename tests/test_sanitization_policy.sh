#!/usr/bin/env bash
# Valida que la política de sanitización cubra las 5 clases (KEEP/MASK/HASH/TOKENIZE/DROP).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
F="$ROOT/sanitizers/data-classification-policy.md"

for cls in KEEP MASK HASH TOKENIZE DROP; do
  if grep -q "\`$cls\`" "$F"; then
    echo "[PASS] $F declara clase $cls"
  else
    echo "[FAIL] $F no declara clase $cls"
    FAIL=1
  fi
done

if grep -q 'RAW DATA' "$F" && grep -q 'SANITIZED EVIDENCE' "$F"; then
  echo "[PASS] Flujo RAW→SANITIZED declarado"
else
  echo "[FAIL] Flujo RAW→SANITIZED no declarado explícitamente"
  FAIL=1
fi

exit $FAIL
