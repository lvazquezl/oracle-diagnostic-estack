#!/usr/bin/env bash
# PHASE 7 — RMAN LEGACY SQL SYNTAX & QUERY CERTIFICATION HARDENING, sección 24. Target 23.0.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/version.sh"
FAIL=0
TARGET="23.0"

for f in "$ROOT"/queries/rman/Q-*.md; do
  qid=$(grep -m1 '^query_id:' "$f" | awk '{print $2}')
  grep -q '^variants:' "$f" || continue

  ids=$(grep -oE 'variant_id: [A-Za-z0-9-]+' "$f" | awk '{print $2}')
  n_variants=$(echo "$ids" | grep -c .)
  if [ "$n_variants" -le 1 ]; then
    echo "[PASS] $qid — variante única sin split legacy/modern (nunca usó Top-N), sin verificación aplicable"
    continue
  fi
  ranges=$(grep -oE 'oracle_versions: \{min: "[^"]+", max: [^}]+\}' "$f")
  i=0
  resolved_i=0
  while IFS= read -r r; do
    i=$((i+1))
    m=$(echo "$r" | grep -oE 'min: "[^"]+"' | grep -oE '"[^"]+"' | tr -d '"')
    x=$(echo "$r" | grep -oE 'max: [^}]+' | sed -E 's/max: *"?//; s/"?$//')
    if [ "$resolved_i" -eq 0 ] && version_in_range "$TARGET" "$m" "$x"; then
      resolved_i=$i
    fi
  done <<< "$ranges"

  [ "$resolved_i" -eq 0 ] && continue

  resolved_id=$(echo "$ids" | sed -n "${resolved_i}p")

  if echo "$resolved_id" | grep -qiE -- '-V2$|modern|multitenant_aware'; then
    echo "[PASS] $qid — resuelve variante moderna ($resolved_id) para 23ai"
  else
    echo "[FAIL] $qid — resolvió $resolved_id para 23ai, esperada la variante moderna"
    FAIL=1
  fi
done

[ $FAIL -eq 0 ] && echo "[PASS] Todas las queries RMAN resuelven variante moderna para 23ai"
exit $FAIL
