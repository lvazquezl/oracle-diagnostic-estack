#!/usr/bin/env bash
# PHASE 6 — FINAL PDB IDENTITY & PATCH-LEVEL RESOLVER HARDENING, # 23, # 39.
# Test de integración real: Q-CDB-PDB-SAVED-STATE-001 + scripts/lib/version.sh.
# 12.1.0.2 -> MATCH / SUPPORTED. 12.2.0.1 -> MATCH / SUPPORTED (ejemplo textual de la # 23 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/version.sh"
FAIL=0
Q="$ROOT/queries/multitenant/Q-CDB-PDB-SAVED-STATE-001.md"

r=$(grep -oE 'oracle_versions: \{min: "[^"]+", max: [^}]+\}' "$Q")
mn=$(echo "$r" | grep -oE 'min: "[^"]+"' | grep -oE '"[^"]+"' | tr -d '"')
mx=$(echo "$r" | grep -oE 'max: "?[^,}"]+' | sed -E 's/max: *"?//')

for target in "12.1.0.2" "12.2.0.1"; do
  if version_in_range "$target" "$mn" "$mx"; then
    echo "[PASS] $target -> MATCH contra Q-CDB-PDB-SAVED-STATE-001 [$mn, $mx]"
  else
    echo "[FAIL] $target no encajó en [$mn, $mx] — debería"
    FAIL=1
  fi
done

exit $FAIL
