#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 69/32.
# Nunca se recolecta wallet password/key material en ninguna query/skill.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
PATTERN='wallet.?password|key.?material|master.?key.*value'

for f in $(find "$ROOT/queries/security" -name 'Q-*.md' 2>/dev/null); do
  block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$f")
  if grep -Eiq "$PATTERN" <<<"$block"; then
    echo "[FAIL] $f parece seleccionar contenido de wallet/key material"
    FAIL=1
  fi
done
[ $FAIL -eq 0 ] && echo "[PASS] Ninguna query Security selecciona wallet password/key material"

# CHG-ESTACK-B7-SECURITY-COVERAGE-001: wrl_parameter (ruta del keystore) ya no se enmascara: nunca se selecciona.
W="$ROOT/queries/security/Q-SEC-TDE-WALLET-001.md"
wblock=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$W")
if grep -qi "wrl_parameter" <<<"$wblock"; then
  echo "[FAIL] Q-SEC-TDE-WALLET-001 selecciona wrl_parameter (ruta del keystore)"; FAIL=1
else
  echo "[PASS] Q-SEC-TDE-WALLET-001 nunca selecciona wrl_parameter"
fi
grep -qi "wrl_parameter.*nunca se selecciona" "$W" \
  && echo "[PASS] Q-SEC-TDE-WALLET-001 documenta que wrl_parameter no sale de la base" \
  || { echo "[FAIL] falta la nota de sanitización de wrl_parameter"; FAIL=1; }

exit $FAIL
