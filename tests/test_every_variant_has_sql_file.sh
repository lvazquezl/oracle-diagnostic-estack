#!/usr/bin/env bash
# Valida que toda variante declarada (variant_id + sql_block) tenga un heading y bloque ```sql
# correspondiente en el mismo archivo (docs/QUERY_VARIANTS.md: sin archivos .sql separados,
# el "sql_file" físico es el heading + fence dentro del Markdown del logical query).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in $(grep -rl '^variants:' "$ROOT/queries" --include='Q-*.md' 2>/dev/null); do
  labels=$(grep -oE 'sql_block: "[^"]+"' "$f" | sed -E 's/sql_block: "(.*)"/\1/')
  while IFS= read -r label; do
    [ -z "$label" ] && continue
    if grep -qF "$label" "$f"; then
      echo "[PASS] $f — heading para '$label' presente"
    else
      echo "[FAIL] $f — declara sql_block '$label' pero no hay heading correspondiente"
      FAIL=1
    fi
  done <<< "$labels"
  n_sql_fences=$(grep -c '```sql' "$f")
  n_labels=$(echo "$labels" | grep -c .)
  if [ "$n_sql_fences" -lt "$n_labels" ]; then
    echo "[FAIL] $f — $n_labels variantes declaradas pero sólo $n_sql_fences bloques \`\`\`sql"
    FAIL=1
  fi
done

exit $FAIL
