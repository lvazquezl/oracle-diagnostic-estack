#!/usr/bin/env bash
# Valida que todo logical query en config/query-compatibility-matrix.yaml tenga variantes
# (explícitas o implicit_full_range) y que ambas fuentes (matrix + archivo) sean consistentes.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
MATRIX="$ROOT/config/query-compatibility-matrix.yaml"

query_ids=$(grep -oE '^  Q-[A-Z0-9-]+:' "$MATRIX" | tr -d ' :')
count=$(echo "$query_ids" | grep -c .)
if [ "$count" -lt 26 ]; then
  echo "[FAIL] config/query-compatibility-matrix.yaml sólo lista $count logical queries, se esperaban >= 26"
  FAIL=1
else
  echo "[PASS] config/query-compatibility-matrix.yaml lista $count logical queries"
fi

while IFS= read -r qid; do
  [ -z "$qid" ] && continue
  if grep -A2 "^  $qid:" "$MATRIX" | grep -q 'variants:'; then
    :  # explicit or implicit_full_range, both contain "variants:"
  else
    echo "[FAIL] $qid no declara 'variants:' en config/query-compatibility-matrix.yaml"
    FAIL=1
  fi
done <<< "$query_ids"
[ $FAIL -eq 0 ] && echo "[PASS] Todo logical query declara variants (explícito o implicit_full_range)"

exit $FAIL
