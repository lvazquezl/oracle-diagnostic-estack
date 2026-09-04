#!/usr/bin/env bash
# network/scan-resolution detecta no-resolution/single-IP/inconsistente/SERVFAIL/timeout (# 30).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/network/scan-resolution/SKILL.md"

for state in RESOLVED NO_RESOLUTION SINGLE_IP_WHERE_MORE_EXPECTED INCONSISTENT_ANSWERS SERVFAIL TIMEOUT; do
  grep -q "$state" "$S" && echo "[PASS] scan-resolution reconoce $state" || { echo "[FAIL] falta $state"; FAIL=1; }
done
grep -qi 'Nunca modifica DNS' "$S" && echo "[PASS] prohibición explícita de modificar DNS" || { echo "[FAIL] falta prohibición"; FAIL=1; }

exit $FAIL
