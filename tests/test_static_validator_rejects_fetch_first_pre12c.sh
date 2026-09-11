#!/usr/bin/env bash
# PHASE 7 — RMAN LEGACY SQL SYNTAX & QUERY CERTIFICATION HARDENING, sección 21/44.
# Fixture negativo controlado (# 21 del prompt): FETCH FIRST con min_version 11.2 declarado ->
# NOT_CERTIFIED. Reproduce check_syntax_features() de tests/test_sql_static_validator.sh de forma
# aislada (no se sourcea el script completo — evita el costo de ~15min de la corrida completa para
# un chequeo unitario) contra el mismo compatibility/oracle-sql-syntax/features.yaml real.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/version.sh"
SYNTAX_FEATURES="$ROOT/compatibility/oracle-sql-syntax/features.yaml"
FAIL=0
HITS=0

get_feature_ids() {
  awk '/^  [A-Za-z_][A-Za-z0-9_]*:[ \t]*$/ { line=$0; sub(/^  /,"",line); sub(/:[ \t]*$/,"",line); print line }' "$SYNTAX_FEATURES"
}
get_feature_block() {
  local target="$1"
  awk -v target="$target" '
    BEGIN{IGNORECASE=1; inf=0}
    /^  [A-Za-z_][A-Za-z0-9_]*:[ \t]*$/ {
      line=$0; sub(/^  /,"",line); sub(/:[ \t]*$/,"",line)
      if (inf && !(tolower(line)==tolower(target))) exit
      inf=(tolower(line)==tolower(target)); next
    }
    inf { print }
  ' "$SYNTAX_FEATURES"
}
check_syntax_features() {
  local block_content="$1" range_min="$2"
  local flat; flat=$(echo "$block_content" | tr '\n' ' ')
  local feature_id
  while IFS= read -r feature_id; do
    [ -z "$feature_id" ] && continue
    local fblock; fblock=$(get_feature_block "$feature_id")
    local feat_min; feat_min=$(echo "$fblock" | grep -m1 '^    min_version:' | sed -E "s/.*min_version:[ \t]*\"?//; s/\"?[ \t]*\$//")
    [ -z "$feat_min" ] && continue
    local patterns; patterns=$(echo "$fblock" | grep -E "^      - '" | sed -E "s/^      - '//; s/'[ \t]*\$//")
    while IFS= read -r pat; do
      [ -z "$pat" ] && continue
      if echo "$flat" | grep -qiE "$pat"; then
        if ! version_gte "$range_min" "$feat_min"; then
          echo "DETECTED: $feature_id requires $feat_min, block declares $range_min"
          HITS=$((HITS+1))
        fi
      fi
    done <<< "$patterns"
  done <<< "$(get_feature_ids)"
}

# Fixture negativo (# 21 del prompt): idéntico al ejemplo del prompt.
FIXTURE='SELECT *
FROM v$rman_status
FETCH FIRST 10 ROWS ONLY;'

check_syntax_features "$FIXTURE" "11.2"

if [ "$HITS" -ge 1 ]; then
  echo "[PASS] Static Validator rechaza FETCH FIRST con min_version 11.2 declarado (NOT_CERTIFIED)"
else
  echo "[FAIL] Static Validator no detectó FETCH FIRST incompatible con min_version 11.2"
  FAIL=1
fi

exit $FAIL
