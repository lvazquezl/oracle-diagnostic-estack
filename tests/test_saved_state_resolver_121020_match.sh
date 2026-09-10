#!/usr/bin/env bash
# PHASE 6 — FINAL PDB IDENTITY & PATCH-LEVEL RESOLVER HARDENING, # 23, # 39.
# Test de integración real: Q-CDB-PDB-SAVED-STATE-001 + scripts/lib/version.sh.
# 12.1.0.2.0 -> MATCH / SUPPORTED — componente "revision" ausente en el min declarado (12.1.0.2)
# se rellena determinísticamente con 0, ambos deben ser equivalentes (# 17 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/version.sh"
FAIL=0
Q="$ROOT/queries/multitenant/Q-CDB-PDB-SAVED-STATE-001.md"

r=$(grep -oE 'oracle_versions: \{min: "[^"]+", max: [^}]+\}' "$Q")
mn=$(echo "$r" | grep -oE 'min: "[^"]+"' | grep -oE '"[^"]+"' | tr -d '"')
mx=$(echo "$r" | grep -oE 'max: "?[^,}"]+' | sed -E 's/max: *"?//')

if version_in_range "12.1.0.2.0" "$mn" "$mx"; then
  echo "[PASS] 12.1.0.2.0 -> MATCH contra Q-CDB-PDB-SAVED-STATE-001 [$mn, $mx]"
else
  echo "[FAIL] 12.1.0.2.0 no encajó en [$mn, $mx] — debería ser equivalente a 12.1.0.2"
  FAIL=1
fi

exit $FAIL
