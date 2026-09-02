#!/usr/bin/env bash
# Ejecuta toda la suite de tests estáticos de Fase 1 y agrega el resultado.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVERALL=0

for t in "$DIR"/test_*.sh; do
  echo "=== $(basename "$t") ==="
  if bash "$t"; then
    echo "--- PASS: $(basename "$t")"
  else
    echo "--- FAIL: $(basename "$t")"
    OVERALL=1
  fi
  echo
done

if [ "$OVERALL" -eq 0 ]; then
  echo "TODOS LOS TESTS PASARON"
else
  echo "AL MENOS UN TEST FALLÓ"
fi
exit $OVERALL
