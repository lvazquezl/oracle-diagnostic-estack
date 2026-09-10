#!/usr/bin/env bash
# PHASE 6 — QUERY COMPATIBILITY & DICTIONARY CERTIFICATION HARDENING, # 6-7, # 9.
# Valida que un target 12.1.0.1 (antes del patch level real de PDB Saved State) no resuelve
# ninguna variante compatible de Q-CDB-PDB-SAVED-STATE-001.
#
# PHASE 6 — FINAL PDB IDENTITY & PATCH-LEVEL RESOLVER HARDENING (# 33 del prompt): refactorizado
# para usar scripts/lib/version.sh (el mismo comparador que tests/test_sql_static_validator.sh y
# tests/test_query_variant_resolver_{10g,11g}.sh) en vez de un vernum3() local — "los tests deben
# usar la misma implementación que el runtime/resolver contract" (# 15 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/version.sh"
FAIL=0
Q="$ROOT/queries/multitenant/Q-CDB-PDB-SAVED-STATE-001.md"
TARGET="12.1.0.1"

match=0
while IFS= read -r r; do
  [ -z "$r" ] && continue
  mn=$(echo "$r" | grep -oE 'min: "[^"]+"' | grep -oE '"[^"]+"' | tr -d '"')
  mx=$(echo "$r" | grep -oE 'max: "?[^,}"]+' | sed -E 's/max: *"?//')
  version_in_range "$TARGET" "$mn" "$mx" && match=1
done < <(grep -oE 'oracle_versions: \{min: "[^"]+", max: [^}]+\}' "$Q")

if [ "$match" -eq 0 ]; then
  echo "[PASS] 12.1.0.1 no resuelve ninguna variante de Q-CDB-PDB-SAVED-STATE-001 (status esperado: UNSUPPORTED)"
else
  echo "[FAIL] 12.1.0.1 resolvió una variante — PDB Saved State no existe en ese patch level (min real 12.1.0.2)"
  FAIL=1
fi

exit $FAIL
