#!/usr/bin/env bash
# Ejecuta toda la suite de tests estáticos del repositorio y agrega el resultado
# (# 41 TEST RUNNER HARDENING: totales + nombres de tests fallidos, sin fail-fast,
# preservando el exit code agregado).
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVERALL=0
TOTAL=0
PASSED=0
declare -a FAILED_TESTS=()

for t in "$DIR"/test_*.sh; do
  name="$(basename "$t")"
  TOTAL=$((TOTAL + 1))
  echo "=== $name ==="
  if bash "$t"; then
    echo "--- PASS: $name"
    PASSED=$((PASSED + 1))
  else
    echo "--- FAIL: $name"
    OVERALL=1
    FAILED_TESTS+=("$name")
  fi
  echo
done

FAILED_COUNT=${#FAILED_TESTS[@]}
echo "================================================================"
echo "RESUMEN: $PASSED/$TOTAL tests OK, $FAILED_COUNT fallaron"
if [ "$FAILED_COUNT" -gt 0 ]; then
  echo "Tests fallidos:"
  for f in "${FAILED_TESTS[@]}"; do
    echo "  - $f"
  done
fi
echo "================================================================"

if [ "$OVERALL" -eq 0 ]; then
  echo "TODOS LOS TESTS PASARON"
else
  echo "AL MENOS UN TEST FALLÓ"
fi
exit $OVERALL
