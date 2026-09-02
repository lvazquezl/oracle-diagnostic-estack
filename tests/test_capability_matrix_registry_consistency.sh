#!/usr/bin/env bash
# Valida que docs/CAPABILITY_MATRIX.md (Markdown) mencione el mismo conjunto de dominios que
# config/capability-matrix.yaml (fuente estructurada), y que ambos referencien el mismo schema.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
YAML="$ROOT/config/capability-matrix.yaml"
MD="$ROOT/docs/CAPABILITY_MATRIX.md"
FAIL=0

display_names=$(grep -oE 'display_name: "[^"]+"' "$YAML" | sed -E 's/display_name: "(.*)"/\1/')

while IFS= read -r name; do
  [ -z "$name" ] && continue
  if grep -Fq "$name" "$MD"; then
    echo "[PASS] Dominio '$name' presente en docs/CAPABILITY_MATRIX.md"
  else
    echo "[FAIL] Dominio '$name' del YAML no aparece en docs/CAPABILITY_MATRIX.md"
    FAIL=1
  fi
done <<< "$display_names"

if grep -q 'fuente estructurada de verdad' "$MD"; then
  echo "[PASS] docs/CAPABILITY_MATRIX.md declara explícitamente al YAML como fuente de verdad"
else
  echo "[FAIL] docs/CAPABILITY_MATRIX.md no declara la relación de consistencia con el YAML"
  FAIL=1
fi

exit $FAIL
