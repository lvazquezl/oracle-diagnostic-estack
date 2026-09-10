#!/usr/bin/env bash
# PHASE 5 — DATA GUARD COMPATIBILITY & QUERY CERTIFICATION HARDENING, sección 15.
# 23ai SÍ debe resolver como compatible en las 7 queries Data Guard (min "10.2", max "23.0") —
# la corrección de "max: latest" -> "max: 23.0" no debe romper la cobertura ya certificada.
#
# PHASE 6 — VERSION RESOLVER CONSOLIDATION FINALIZATION (# 6, # 14 del prompt): usa
# scripts/lib/version.sh en vez de un vernum() local.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/version.sh"
FAIL=0
TARGET="23.0"

for f in $ROOT/queries/dataguard/Q-DG-*.md; do
  qid=$(grep -m1 '^query_id:' "$f" | awk '{print $2}')
  mins=$(grep -oE 'oracle_versions: \{min: "[0-9]+\.[0-9]+", max: "[0-9]+\.[0-9]+"' "$f" 2>/dev/null)
  if [ -z "$mins" ]; then
    # implicit_full_range: leer min/max desde config/query-compatibility-matrix.yaml
    line=$(grep -m1 "^  $qid:" "$ROOT/config/query-compatibility-matrix.yaml")
    mn=$(echo "$line" | grep -oE 'min: "[0-9.]+"' | grep -oE '[0-9.]+')
    mx=$(echo "$line" | grep -oE 'max: "[0-9.]+"' | grep -oE '[0-9.]+')
    [ -z "$mn" ] && mn="10.2"
    [ -z "$mx" ] && mx="23.0"
    if version_in_range "$TARGET" "$mn" "$mx"; then
      echo "[PASS] $qid — resuelve compatible para 23ai (min $mn, max $mx)"
    else
      echo "[FAIL] $qid — NO resuelve para 23ai (min $mn, max $mx) — regresión de cobertura ya certificada"
      FAIL=1
    fi
  else
    while IFS= read -r r; do
      mn=$(echo "$r" | grep -oE 'min: "[^"]+"' | grep -oE '"[^"]+"' | tr -d '"')
      mx=$(echo "$r" | grep -oE 'max: "[^"]+"' | grep -oE '"[^"]+"' | tr -d '"')
      if version_in_range "$TARGET" "$mn" "$mx"; then
        echo "[PASS] $qid — variante resuelve compatible para 23ai (min $mn, max $mx)"
      fi
    done <<< "$mins"
  fi
done

[ $FAIL -eq 0 ] && echo "[PASS] 23ai sigue certificado como compatible en todas las queries Data Guard tras el fix de max explícito"

exit $FAIL
