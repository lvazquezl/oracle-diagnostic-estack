#!/usr/bin/env bash
# PHASE 6 — QUERY COMPATIBILITY & DICTIONARY CERTIFICATION HARDENING, # 25.
# Positivo: toda vista referenciada por las 15 queries multitenant reales está registrada en el
# dictionary. Negativo (fixture conceptual, # 25 del prompt: "SELECT * FROM fake_multitenant_view"
# -> NOT_CERTIFIED): una vista fabricada nunca aparece registrada — no se inyecta un archivo falso
# en queries/ real, se valida el predicado de lookup del que depende ese resultado.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
DICT="$ROOT/compatibility/oracle-dictionary/views.yaml"

view_registered() {
  local v="$1"
  awk -v target="$v" 'BEGIN{IGNORECASE=1} /^  [A-Za-z$#0-9_]+:[ \t]*$/{line=$0; sub(/^  /,"",line); sub(/:[ \t]*$/,"",line); if (tolower(line)==tolower(target)) {found=1; exit}} END{exit !found}' "$DICT"
}

for f in "$ROOT"/queries/multitenant/Q-*.md; do
  views=$(grep -m1 '^objects_accessed:' "$f" | sed -E 's/objects_accessed: *\[(.*)\]/\1/' | tr ',' '\n' | sed -E 's/^ *//; s/ *$//')
  while IFS= read -r v; do
    [ -z "$v" ] && continue
    if view_registered "$v"; then
      echo "[PASS] $(basename "$f") — '$v' está registrada en el dictionary"
    else
      echo "[FAIL] $(basename "$f") — '$v' NO está registrada (NOT_CERTIFIED)"
      FAIL=1
    fi
  done <<< "$views"
done

if view_registered "FAKE_MULTITENANT_VIEW"; then
  echo "[FAIL] FAKE_MULTITENANT_VIEW aparece registrada — el dictionary certificaría una vista inexistente"
  FAIL=1
else
  echo "[PASS] FAKE_MULTITENANT_VIEW no está registrada — 'SELECT * FROM fake_multitenant_view' sería NOT_CERTIFIED"
fi

exit $FAIL
