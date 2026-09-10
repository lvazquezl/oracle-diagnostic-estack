#!/usr/bin/env bash
# PHASE 6 — QUERY COMPATIBILITY & DICTIONARY CERTIFICATION HARDENING, # 18.
# Valida que el Query Variant Resolver resuelve legacy para 12.1 y modern para 12.2+ — nunca
# ambas, nunca ninguna dentro del rango certificado.
#
# PHASE 6 — VERSION RESOLVER CONSOLIDATION FINALIZATION (# 5-6 del prompt): usa
# scripts/lib/version.sh en vez de un vernum() local.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/version.sh"
FAIL=0
Q="$ROOT/queries/multitenant/Q-CDB-PLUGIN-VIOLATIONS-001.md"

# oracle_versions aparece en el mismo orden que los variant_id en el frontmatter — V1 (legacy)
# primero, V2 (modern) segundo. No se re-extrae variant_id por línea (min/max viven en la línea
# siguiente en este formato multi-línea) — se empareja posicionalmente, mismo criterio que
# tests/test_pdb_saved_state_1210*.sh.
ranges=$(grep -oE 'oracle_versions: \{min: "[^"]+", max: [^}]+\}' "$Q")
labels=("legacy_121_no_con_id" "modern_122plus_con_id")

resolve() {
  local target="$1"
  local resolved=""
  local idx=0
  while IFS= read -r r; do
    [ -z "$r" ] && continue
    mn=$(echo "$r" | grep -oE 'min: "[^"]+"' | grep -oE '"[^"]+"' | tr -d '"')
    mx=$(echo "$r" | grep -oE 'max: "?[^,}"]+' | sed -E 's/max: *"?//')
    if version_in_range "$target" "$mn" "$mx"; then
      resolved="$resolved ${labels[$idx]}"
    fi
    idx=$((idx+1))
  done <<< "$ranges"
  echo "$resolved" | xargs
}

r121=$(resolve "12.1")
[ "$r121" = "legacy_121_no_con_id" ] && echo "[PASS] 12.1 resuelve únicamente la variante legacy" || { echo "[FAIL] 12.1 resolvió '$r121', esperado únicamente legacy_121_no_con_id"; FAIL=1; }

r122=$(resolve "12.2")
[ "$r122" = "modern_122plus_con_id" ] && echo "[PASS] 12.2 resuelve únicamente la variante moderna" || { echo "[FAIL] 12.2 resolvió '$r122', esperado únicamente modern_122plus_con_id"; FAIL=1; }

r190=$(resolve "19.0")
[ "$r190" = "modern_122plus_con_id" ] && echo "[PASS] 19.0 resuelve únicamente la variante moderna" || { echo "[FAIL] 19.0 resolvió '$r190', esperado únicamente modern_122plus_con_id"; FAIL=1; }

exit $FAIL
