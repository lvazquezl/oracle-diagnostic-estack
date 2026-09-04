#!/usr/bin/env bash
# Valida que output-schema.yaml declare performance_result con las claves requeridas
# (# 31 OUTPUT SCHEMA).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
O="$ROOT/agents/oracle-performance-analyst/output-schema.yaml"

[ -f "$O" ] || { echo "[FAIL] falta output-schema.yaml"; exit 1; }

grep -q '^performance_result:' "$O" && echo "[PASS] declara performance_result" || { echo "[FAIL] falta performance_result"; FAIL=1; }

for field in summary workload bottlenecks findings hypotheses evidence_refs recommendations manual_actions limitations confidence; do
  if grep -qE "^  $field:" "$O"; then
    echo "[PASS] performance_result declara $field"
  else
    echo "[FAIL] performance_result no declara $field"
    FAIL=1
  fi
done

# CONFIRMED_ROOT_CAUSE puede mencionarse en un comentario explicando la prohibición — el chequeo
# real es que no aparezca como valor dentro de la enumeración quoteada de "confidence".
confidence_line=$(grep -A1 '^  confidence:' "$O" | head -1)
if echo "$confidence_line" | grep -q 'CONFIRMED_ROOT_CAUSE'; then
  echo "[FAIL] output-schema.yaml permite CONFIRMED_ROOT_CAUSE como valor de confidence"
  FAIL=1
else
  echo "[PASS] CONFIRMED_ROOT_CAUSE no es un valor permitido de confidence"
fi

exit $FAIL
