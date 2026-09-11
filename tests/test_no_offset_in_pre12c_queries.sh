#!/usr/bin/env bash
# PHASE 7 — RMAN LEGACY SQL SYNTAX & QUERY CERTIFICATION HARDENING, sección 26 — mismo principio
# que test_no_fetch_first_in_pre12c_queries.sh, aplicado a OFFSET ... ROWS.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/version.sh"
FAIL=0
PATTERN='OFFSET[[:space:]]+[0-9]+[[:space:]]+ROWS?'

check_file_variants() {
  local f="$1"
  local mins
  mins=$(grep -oE 'oracle_versions: \{min: "[0-9]+(\.[0-9]+){1,3}"' "$f" | grep -oE '"[0-9]+(\.[0-9]+){1,3}"' | tr -d '"')
  local i=0
  while IFS= read -r min; do
    [ -z "$min" ] && continue
    i=$((i+1))
    local block
    block=$(awk -v n="$i" '/```sql/{c++} c==n && /```sql/{flag=1;next} flag && /```/{flag=0} flag' "$f")
    if echo "$block" | grep -qiE "$PATTERN"; then
      if ! version_gte "$min" "12.1"; then
        echo "[FAIL] $f — variante #$i (min declarado $min) usa OFFSET ... ROWS, que requiere 12.1+"
        FAIL=1
      fi
    fi
  done <<< "$mins"
}

for f in $(grep -rl '^variants:' "$ROOT/queries" --include='Q-*.md' 2>/dev/null); do
  check_file_variants "$f"
done

for f in $(grep -rL '^variants:' "$ROOT/queries" --include='Q-*.md' 2>/dev/null); do
  raw=$(grep -oE '^supported_oracle_versions: \[[^]]*\]' "$f" | head -1)
  first=$(echo "$raw" | sed -E 's/.*\[([^],]*).*/\1/' | tr -d ' ')
  case "$first" in
    10g) min="10.2" ;;
    11g|11gR2) min="11.0" ;;
    12c) min="12.1" ;;
    18c) min="18.0" ;;
    19c) min="19.0" ;;
    21c) min="21.0" ;;
    23ai) min="23.0" ;;
    *) min="10.2" ;;
  esac
  nblocks=$(grep -c '```sql' "$f" || true)
  i=0
  while [ "$i" -lt "$nblocks" ]; do
    i=$((i+1))
    block=$(awk -v n="$i" '/```sql/{c++} c==n && /```sql/{flag=1;next} flag && /```/{flag=0} flag' "$f")
    if echo "$block" | grep -qiE "$PATTERN"; then
      if ! version_gte "$min" "12.1"; then
        echo "[FAIL] $f — bloque #$i (min declarado $min) usa OFFSET ... ROWS, que requiere 12.1+"
        FAIL=1
      fi
    fi
  done
done

[ $FAIL -eq 0 ] && echo "[PASS] Ninguna query certificada con min_version < 12.1 usa OFFSET ... ROWS en todo el catálogo"
exit $FAIL
