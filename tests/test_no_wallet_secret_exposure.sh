#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 69/32.
# Nunca se recolecta wallet password/key material en ninguna query/skill.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
PATTERN='wallet.?password|key.?material|master.?key.*value'

for f in $(find "$ROOT/queries/security" -name 'Q-*.md' 2>/dev/null); do
  block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$f")
  if echo "$block" | grep -Eiq "$PATTERN"; then
    echo "[FAIL] $f parece seleccionar contenido de wallet/key material"
    FAIL=1
  fi
done
[ $FAIL -eq 0 ] && echo "[PASS] Ninguna query Security selecciona wallet password/key material"

grep -qi "wrl_parameter.*→ MASK\|wrl_parameter → MASK" "$ROOT/queries/security/Q-SEC-TDE-WALLET-001.md" \
  && echo "[PASS] Q-SEC-TDE-WALLET-001 sanitiza wrl_parameter" \
  || { echo "[FAIL] falta la sanitización de wrl_parameter"; FAIL=1; }

exit $FAIL
