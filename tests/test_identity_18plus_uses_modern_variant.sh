#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
F="$ROOT/queries/oracle/discovery/Q-DISC-IDENTITY-001.md"
v3=$(awk '/^# Statement \/ procedure \(read-only\).*Variant V3/{f=1} f&&/```sql/{c=1;next} c&&/```/{exit} c' "$F" | sed -E 's/--.*$//')
if echo "$v3" | grep -qi 'version_full'; then
  echo "[PASS] Variant V3 (18c+) usa version_full correctamente"
else
  echo "[FAIL] Variant V3 (18c+) no usa version_full — debería, es válida desde 18.0"
  exit 1
fi
