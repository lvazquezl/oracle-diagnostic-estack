#!/usr/bin/env bash
# PHASE 5 — DATA GUARD FINAL PROCESS-VIEW & PORTABILITY HARDENING, sección 10-11.
# Sobre 19c (1900) sólo la variante moderna debe resolver — V$MANAGED_STANDBY está deprecada
# desde 12.2.0.1, ya no es un default universal permanente (# 8).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/dataguard/Q-DG-MANAGED-PROCESS-001.md"
TARGET=1900

vernum() { local v="$1"; local maj min; maj=$(echo "$v"|cut -d. -f1); min=$(echo "$v"|cut -d. -f2); echo $((maj*100+min)); }

mins=$(grep -oE 'oracle_versions: \{min: "[0-9]+\.[0-9]+", max: "[0-9]+\.[0-9]+"' "$Q")
found_v1=0 found_v2=0
while IFS= read -r r; do
  mn=$(echo "$r" | grep -oE 'min: "[^"]+"' | grep -oE '"[^"]+"' | tr -d '"')
  mx=$(echo "$r" | grep -oE 'max: "[^"]+"' | grep -oE '"[^"]+"' | tr -d '"')
  mnn=$(vernum "$mn"); mxn=$(vernum "$mx")
  if [ "$TARGET" -ge "$mnn" ] && [ "$TARGET" -le "$mxn" ]; then
    [ "$mn" = "10.2" ] && found_v1=1
    [ "$mn" = "12.2" ] && found_v2=1
  fi
done <<< "$mins"

[ "$found_v1" -eq 0 ] && echo "[PASS] variante legacy NO resuelve para 19c — deprecada desde 12.2.0.1" || { echo "[FAIL] la variante legacy resolvió para 19c — no debería"; FAIL=1; }
[ "$found_v2" -eq 1 ] && echo "[PASS] variante moderna resuelve para 19c" || { echo "[FAIL] variante moderna no resuelve para 19c"; FAIL=1; }

exit $FAIL
