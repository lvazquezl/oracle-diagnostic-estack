#!/usr/bin/env bash
# PHASE 7 — RMAN LEGACY SQL SYNTAX & QUERY CERTIFICATION HARDENING, sección 24.
# Mismo principio que test_rman_legacy_variant_10g.sh, target 11.2 (11gR2).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/version.sh"
FAIL=0
TARGET="11.2"

for f in "$ROOT"/queries/rman/Q-*.md; do
  qid=$(grep -m1 '^query_id:' "$f" | awk '{print $2}')
  grep -q '^variants:' "$f" || continue

  ids=$(grep -oE 'variant_id: [A-Za-z0-9-]+' "$f" | awk '{print $2}')
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
  block=$(awk -v n="$resolved_i" '/```sql/{c++} c==n && /```sql/{flag=1;next} flag && /```/{flag=0} flag' "$f")

  if echo "$resolved_id" | grep -qi -- '-V1$\|legacy'; then
    echo "[PASS] $qid — resuelve variante legacy ($resolved_id) para 11g"
  else
    echo "[FAIL] $qid — resolvió $resolved_id para 11g, esperada la variante legacy"
    FAIL=1
  fi

  if echo "$block" | grep -qiE 'FETCH[[:space:]]+(FIRST|NEXT)|OFFSET[[:space:]]+[0-9]'; then
    echo "[FAIL] $qid — variante resuelta para 11g ($resolved_id) usa FETCH FIRST/OFFSET, incompatible con 11g"
    FAIL=1
  fi
done

[ $FAIL -eq 0 ] && echo "[PASS] Todas las queries RMAN resuelven variante legacy sin sintaxis 12c+ para 11g"
exit $FAIL
