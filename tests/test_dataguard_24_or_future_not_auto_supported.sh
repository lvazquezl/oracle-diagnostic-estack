#!/usr/bin/env bash
# PHASE 5 — DATA GUARD COMPATIBILITY & QUERY CERTIFICATION HARDENING, sección 15.
# Una major Oracle futura y desconocida (representada aquí como 24.0) NO debe resolver como
# compatible en ninguna query Data Guard — es exactamente el defecto que el resolver tenía con
# "max: latest" -> vernum("latest") = 99999 (techo sin límite real).
#
# PHASE 6 — VERSION RESOLVER CONSOLIDATION FINALIZATION (# 6, # 14 del prompt): usa
# scripts/lib/version.sh en vez de un vernum() local.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/version.sh"
FAIL=0
TARGET="24.0"

for f in $ROOT/queries/dataguard/Q-DG-*.md; do
  qid=$(grep -m1 '^query_id:' "$f" | awk '{print $2}')
  mins=$(grep -oE 'oracle_versions: \{min: "[0-9]+\.[0-9]+", max: "[0-9]+\.[0-9]+"' "$f" 2>/dev/null)
  if [ -z "$mins" ]; then
    line=$(grep -m1 "^  $qid:" "$ROOT/config/query-compatibility-matrix.yaml")
    mx=$(echo "$line" | grep -oE 'max: "[0-9.]+"' | grep -oE '[0-9.]+')
    [ -z "$mx" ] && mx="23.0"
    if version_lte "$TARGET" "$mx"; then
      echo "[FAIL] $qid — 24.0 resuelve como compatible (max declarado: $mx) — esperado: NO match / COMPATIBILITY_VALIDATION_REQUIRED"
      FAIL=1
    else
      echo "[PASS] $qid — 24.0 correctamente NO resuelve como compatible (max declarado: $mx)"
    fi
  else
    while IFS= read -r r; do
      mx=$(echo "$r" | grep -oE 'max: "[^"]+"' | grep -oE '"[^"]+"' | tr -d '"')
      if version_lte "$TARGET" "$mx"; then
        echo "[FAIL] $qid — variante con max $mx resuelve 24.0 como compatible — esperado: NO match"
        FAIL=1
      else
        echo "[PASS] $qid — variante (max $mx) correctamente NO resuelve 24.0 como compatible"
      fi
    done <<< "$mins"
  fi
done

# Ningún "max: latest" literal debe quedar en el bloque Data Guard de la matriz.
if awk '/Fase 5 \(Data Guard\)/{flag=1} flag{print} /^notes: >/{flag=0}' "$ROOT/config/query-compatibility-matrix.yaml" | grep -q 'max: latest'; then
  echo "[FAIL] todavía queda un 'max: latest' literal en el bloque Data Guard de query-compatibility-matrix.yaml"
  FAIL=1
fi

[ $FAIL -eq 0 ] && echo "[PASS] Ninguna query Data Guard hereda soporte automático para una major futura desconocida (24.x)"

exit $FAIL
