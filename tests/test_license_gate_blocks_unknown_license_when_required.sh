#!/usr/bin/env bash
# Valida que la secuencia de gate de licensing bloquee (LICENSE_RESTRICTED) cuando la licencia
# no se puede confirmar, en vez de asumir que está disponible.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
F="$ROOT/policies/licensing-awareness-policy.md"

if grep -q 'License check' "$F" && grep -q 'Capability requested' "$F"; then
  echo "[PASS] licensing-awareness-policy.md declara la secuencia de gate completa"
else
  echo "[FAIL] licensing-awareness-policy.md no declara la secuencia de gate"
  FAIL=1
fi

if grep -q 'LICENSE_RESTRICTED' "$F"; then
  echo "[PASS] licensing-awareness-policy.md referencia el estado LICENSE_RESTRICTED cuando no se puede confirmar la licencia"
else
  echo "[FAIL] licensing-awareness-policy.md no referencia LICENSE_RESTRICTED"
  FAIL=1
fi

if grep -q 'Ninguna recomendación asume licencia disponible' "$F"; then
  echo "[PASS] Principio 'nunca asumir licencia disponible' presente"
else
  echo "[FAIL] Falta el principio de no asumir licencia disponible"
  FAIL=1
fi

exit $FAIL
