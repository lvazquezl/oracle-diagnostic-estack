#!/usr/bin/env bash
# Valida que toda vista en required_views de config/query-compatibility-matrix.yaml esté
# registrada en compatibility/oracle-dictionary/views.yaml (fuente de verdad de disponibilidad).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
MATRIX="$ROOT/config/query-compatibility-matrix.yaml"
DICT="$ROOT/compatibility/oracle-dictionary/views.yaml"

views=$(grep -oE 'required_views: \[[^]]*\]' "$MATRIX" | grep -oE '\[[^]]*\]' | tr -d '[]' | tr ',' '\n' | sed -E 's/^ *"?//; s/"? *$//' | sort -u)

while IFS= read -r view; do
  [ -z "$view" ] && continue
  [ "$view" = "alert.log" ] && continue   # archivo, no vista de diccionario
  if grep -q "^  $view:" "$DICT"; then
    echo "[PASS] $view registrada en compatibility/oracle-dictionary/views.yaml"
  else
    echo "[FAIL] $view referenciada en query-compatibility-matrix.yaml pero no está en el dictionary"
    FAIL=1
  fi
done <<< "$views"

exit $FAIL
