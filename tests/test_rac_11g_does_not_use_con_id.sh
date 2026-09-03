#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
F="$ROOT/queries/oracle/discovery/Q-DISC-RAC-001.md"
v1=$(awk '/^# Statement \/ procedure \(read-only\).*Variant V1/{f=1} f&&/```sql/{c=1;next} c&&/```/{exit} c' "$F" | sed -E 's/--.*$//')
if echo "$v1" | grep -qi 'con_id'; then
  echo "[FAIL] Variant V1 (11.2, pre-multitenant) usa con_id"
  exit 1
fi
echo "[PASS] Variant V1 (11.2) no usa con_id"
