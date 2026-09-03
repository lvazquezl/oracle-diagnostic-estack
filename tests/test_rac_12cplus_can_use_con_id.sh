#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
F="$ROOT/queries/oracle/discovery/Q-DISC-RAC-001.md"
v2=$(awk '/^# Statement \/ procedure \(read-only\).*Variant V2/{f=1} f&&/```sql/{c=1;next} c&&/```/{exit} c' "$F" | sed -E 's/--.*$//')
if echo "$v2" | grep -qi 'con_id'; then
  echo "[PASS] Variant V2 (12.1+) usa con_id correctamente"
else
  echo "[FAIL] Variant V2 (12.1+) no usa con_id — debería, es válida desde 12.1"
  exit 1
fi
