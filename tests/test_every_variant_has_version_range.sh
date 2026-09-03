#!/usr/bin/env bash
# Valida que toda variante explícita (frontmatter variants: en un archivo de query) declare min/max.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in $(grep -rl '^variants:' "$ROOT/queries" --include='Q-*.md' 2>/dev/null); do
  n_variant_ids=$(grep -c 'variant_id:' "$f")
  n_min=$(grep -cE 'oracle_versions: \{min:' "$f")
  if [ "$n_variant_ids" -eq "$n_min" ] && [ "$n_variant_ids" -ge 1 ]; then
    echo "[PASS] $f — $n_variant_ids variante(s), todas con oracle_versions.min declarado"
  else
    echo "[FAIL] $f — $n_variant_ids variant_id(s) pero $n_min con oracle_versions.min"
    FAIL=1
  fi
done

exit $FAIL
