#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
F="$ROOT/queries/oracle/discovery/Q-DISC-IDENTITY-001.md"
v1=$(awk '/^# Statement \/ procedure \(read-only\).*Variant V1/{f=1} f&&/```sql/{c=1;next} c&&/```/{exit} c' "$F")
if echo "$v1" | sed -E 's/--.*$//' | grep -qi 'version_full'; then
  echo "[FAIL] Variant V1 (10g/11g legacy) usa version_full"
  exit 1
fi
echo "[PASS] Variant V1 (legacy 10g/11g) no usa version_full"
