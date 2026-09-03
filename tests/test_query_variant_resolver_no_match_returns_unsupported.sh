#!/usr/bin/env bash
# Valida que docs/QUERY_VARIANTS.md documente explícitamente el estado UNSUPPORTED (nunca
# fallback silencioso ni "ejecutar la versión más cercana") cuando ninguna variante coincide.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
F="$ROOT/docs/QUERY_VARIANTS.md"

grep -q '^status: UNSUPPORTED$' "$F" && echo "[PASS] docs/QUERY_VARIANTS.md documenta status: UNSUPPORTED para no-match" || { echo "[FAIL] falta el ejemplo de status UNSUPPORTED"; FAIL=1; }
grep -qi 'nunca fallback silencioso' "$F" && echo "[PASS] docs/QUERY_VARIANTS.md prohíbe fallback silencioso" || { echo "[FAIL] falta la prohibición de fallback silencioso"; FAIL=1; }
grep -qi 'nunca.*ejecutar la versión más cercana\|nunca.*closest version' "$F" && echo "[PASS] docs/QUERY_VARIANTS.md prohíbe 'ejecutar la versión más cercana'" || { echo "[FAIL] falta la prohibición de 'closest version'"; FAIL=1; }

# Verificacion real: Q-DISC-RAC-001 no tiene variante para 10.2 (RAC pre-11gR2) -> debe
# comportarse como no-match, ya validado por test_query_variant_resolver_10g.sh; aqui sólo
# confirmamos que el caso exista en el catálogo (no es un ejemplo teórico).
resolver_10g_output=$(bash "$ROOT/tests/test_query_variant_resolver_10g.sh")
if echo "$resolver_10g_output" | grep -q 'Q-DISC-RAC-001 — sin variante'; then
  echo "[PASS] Existe un caso real de no-match en el catálogo (Q-DISC-RAC-001 sobre 10g)"
else
  echo "[FAIL] No se encontró un caso real de no-match para validar el comportamiento"
  FAIL=1
fi

exit $FAIL
