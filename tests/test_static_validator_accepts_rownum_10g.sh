#!/usr/bin/env bash
# PHASE 7 — RMAN LEGACY SQL SYNTAX & QUERY CERTIFICATION HARDENING, sección 23/44.
# Fixture positivo legacy controlado (# 23 del prompt): ROWNUM sobre inline view ya ordenado, con
# min_version 10.2 declarado -> CERTIFIED (ROWNUM nunca está en compatibility/oracle-sql-syntax/
# features.yaml — no es una feature version-gated, es sintaxis Oracle desde siempre).
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

# Fixture legacy positivo (# 23 del prompt): idéntico al ejemplo del prompt — ORDER BY dentro del
# inline view, ROWNUM aplicado fuera.
FIXTURE='SELECT *
FROM (
    SELECT *
    FROM v$rman_status
    ORDER BY start_time DESC
)
WHERE ROWNUM <= 10;'

check_syntax_features "$FIXTURE" "10.2"

if [ "$HITS" -eq 0 ]; then
  echo "[PASS] Static Validator acepta ROWNUM sobre inline view ordenado con min_version 10.2 (CERTIFIED)"
else
  echo "[FAIL] Static Validator rechazó incorrectamente sintaxis ROWNUM legacy válida desde 10g"
  FAIL=1
fi

# Verifica además que el ORDER BY está dentro del inline view (# 30 del prompt: nunca ROWNUM antes
# de ordenar) — chequeo estructural simple, no un parser SQL completo.
if echo "$FIXTURE" | grep -qE 'ROWNUM.*ORDER BY'; then
  echo "[FAIL] ORDER BY aparece después de ROWNUM en el fixture — violaría el ordering correcto"
  FAIL=1
else
  echo "[PASS] ORDER BY precede a ROWNUM (dentro del inline view)"
fi

exit $FAIL
