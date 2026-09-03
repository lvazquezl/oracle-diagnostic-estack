#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
F="$ROOT/queries/oracle/discovery/Q-DISC-IDENTITY-001.md"
v2=$(awk '/^# Statement \/ procedure \(read-only\).*Variant V2/{f=1} f&&/```sql/{c=1;next} c&&/```/{exit} c' "$F" | sed -E 's/--.*$//')
if echo "$v2" | grep -qi '\bd\.cdb\b'; then
  echo "[PASS] Variant V2 (12c) usa d.cdb correctamente"
else
  echo "[FAIL] Variant V2 (12c) no usa d.cdb — debería, es válida desde 12.1"
  exit 1
fi
