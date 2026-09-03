#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
F="$ROOT/queries/oracle/discovery/Q-DISC-IDENTITY-001.md"
v1=$(awk '/^# Statement \/ procedure \(read-only\).*Variant V1/{f=1} f&&/```sql/{c=1;next} c&&/```/{exit} c' "$F" | sed -E 's/--.*$//')
if echo "$v1" | grep -qi '\bd\.cdb\b'; then
  echo "[FAIL] Variant V1 (11g) usa d.cdb"
  exit 1
fi
echo "[PASS] Variant V1 (11g, cubre hasta 11.2) no usa d.cdb"
