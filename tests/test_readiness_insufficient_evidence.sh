#!/usr/bin/env bash
# Ambos skills de readiness declaran INSUFFICIENT_EVIDENCE como resultado válido.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for s in switchover-readiness failover-readiness; do
  S="$ROOT/skills/dataguard/$s/SKILL.md"
  grep -q 'INSUFFICIENT_EVIDENCE' "$S" && echo "[PASS] $s declara INSUFFICIENT_EVIDENCE" || { echo "[FAIL] $s no declara INSUFFICIENT_EVIDENCE"; FAIL=1; }
done

exit $FAIL
