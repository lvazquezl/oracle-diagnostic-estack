#!/usr/bin/env bash
# PHASE 6 — FINAL PDB IDENTITY & PATCH-LEVEL RESOLVER HARDENING, # 23, # 39.
# Test de integración real: Q-CDB-PDB-SAVED-STATE-001 + scripts/lib/version.sh (el mismo comparador
# compartido, no un helper local). 12.1.0.1 -> NO MATCH / UNSUPPORTED.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/version.sh"
FAIL=0
Q="$ROOT/queries/multitenant/Q-CDB-PDB-SAVED-STATE-001.md"

r=$(grep -oE 'oracle_versions: \{min: "[^"]+", max: [^}]+\}' "$Q")
mn=$(echo "$r" | grep -oE 'min: "[^"]+"' | grep -oE '"[^"]+"' | tr -d '"')
mx=$(echo "$r" | grep -oE 'max: "?[^,}"]+' | sed -E 's/max: *"?//')

if version_in_range "12.1.0.1" "$mn" "$mx"; then
  echo "[FAIL] 12.1.0.1 encajó en [$mn, $mx] — no debería, PDB Saved State no existe en ese patch level"
  FAIL=1
else
  echo "[PASS] 12.1.0.1 -> NO MATCH contra Q-CDB-PDB-SAVED-STATE-001 [$mn, $mx] (integración real con scripts/lib/version.sh)"
fi

exit $FAIL
