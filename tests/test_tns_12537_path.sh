#!/usr/bin/env bash
# TNS-12537 documentado en knowledge base — nunca reducido automáticamente a listener (# 52).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

KC="$ROOT/knowledge/errors/tns/TNS-12537-connection-closed.md"
[ -f "$KC" ] && echo "[PASS] TNS-12537 knowledge entry existe" || { echo "[FAIL] falta la entrada de knowledge"; FAIL=1; }
grep -qi 'no reducir automáticamente a listener' "$ROOT/skills/network/tns-errors/SKILL.md" \
  && echo "[PASS] network/tns-errors no reduce TNS-12537 automáticamente a listener" \
  || { echo "[FAIL] falta la regla explícita"; FAIL=1; }

exit $FAIL
