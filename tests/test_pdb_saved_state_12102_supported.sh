#!/usr/bin/env bash
# PHASE 6 — QUERY COMPATIBILITY & DICTIONARY CERTIFICATION HARDENING, # 6-7, # 9.
# Valida que un target 12.1.0.2 (el patch level real donde PDB Saved State existe) sí resuelve la
# variante V1 de Q-CDB-PDB-SAVED-STATE-001.
#
# PHASE 6 — FINAL PDB IDENTITY & PATCH-LEVEL RESOLVER HARDENING (# 33 del prompt): refactorizado
# para usar scripts/lib/version.sh en vez de un vernum3() local — mismo criterio que
# test_pdb_saved_state_12101_not_supported.sh.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/version.sh"
FAIL=0
Q="$ROOT/queries/multitenant/Q-CDB-PDB-SAVED-STATE-001.md"

resolves() {
  local target="$1"
  local m=0
  while IFS= read -r r; do
    [ -z "$r" ] && continue
    mn=$(echo "$r" | grep -oE 'min: "[^"]+"' | grep -oE '"[^"]+"' | tr -d '"')
    mx=$(echo "$r" | grep -oE 'max: "?[^,}"]+' | sed -E 's/max: *"?//')
    version_in_range "$target" "$mn" "$mx" && m=1
  done < <(grep -oE 'oracle_versions: \{min: "[^"]+", max: [^}]+\}' "$Q")
  [ "$m" -eq 1 ]
}

resolves "12.1.0.2" && echo "[PASS] 12.1.0.2 resuelve la variante V1 de Q-CDB-PDB-SAVED-STATE-001 (status esperado: SUPPORTED)" || { echo "[FAIL] 12.1.0.2 no resolvió ninguna variante — debería, es el patch level mínimo real"; FAIL=1; }

for extra in "12.2" "19.0" "23.0"; do
  if resolves "$extra"; then
    echo "[PASS] $extra resuelve la variante V1"
  else
    echo "[FAIL] $extra no resolvió ninguna variante"
    FAIL=1
  fi
done

exit $FAIL
