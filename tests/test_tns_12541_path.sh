#!/usr/bin/env bash
# TNS-12541 documentado en knowledge base y cubierto por network/connection-path.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

KC="$ROOT/knowledge/errors/tns/TNS-12541-no-listener.md"
[ -f "$KC" ] && echo "[PASS] TNS-12541 knowledge entry existe" || { echo "[FAIL] falta la entrada de knowledge"; FAIL=1; }
grep -q 'TNS-12541' "$ROOT/skills/network/tns-errors/SKILL.md" && echo "[PASS] network/tns-errors referencia TNS-12541" || { echo "[FAIL] falta la referencia en tns-errors"; FAIL=1; }

exit $FAIL
