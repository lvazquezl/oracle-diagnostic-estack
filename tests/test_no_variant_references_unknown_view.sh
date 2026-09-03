#!/usr/bin/env bash
# Valida que toda vista usada en un bloque SQL de cada query este registrada en
# compatibility/oracle-dictionary/views.yaml (vista "desconocida" = no inventariada).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
DICT="$ROOT/compatibility/oracle-dictionary/views.yaml"

known_views=$(grep -oE '^  [A-Z][A-Z0-9_$]*:' "$DICT" | tr -d ' :')

for f in $(find "$ROOT/queries" -name 'Q-*.md'); do
  declared=$(grep -oE '^objects_accessed: \[[^]]*\]' "$f" | grep -oE '\[[^]]*\]' | tr -d '[]' | tr ',' '\n' | sed -E 's/^ *//; s/ *$//')
  while IFS= read -r obj; do
    [ -z "$obj" ] && continue
    case "$obj" in alert.log|*"("*) continue ;; esac  # archivos y notas parentéticas, no vistas SQL
    if echo "$known_views" | grep -qFx "$obj"; then
      :
    else
      echo "[FAIL] $f declara objects_accessed '$obj' no registrada en compatibility/oracle-dictionary/views.yaml"
      FAIL=1
    fi
  done <<< "$declared"
done
[ $FAIL -eq 0 ] && echo "[PASS] Ninguna query referencia una vista fuera del dictionary de compatibilidad"

exit $FAIL
