#!/usr/bin/env bash
# PHASE 5 — DATA GUARD FINAL PROCESS-VIEW & PORTABILITY HARDENING, sección 10-11.
# Sobre 12.2 (1202, el límite inferior exacto del rango moderno — versión real de introducción de
# V$DATAGUARD_PROCESS según Oracle Database Reference) sólo la variante moderna debe resolver.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/dataguard/Q-DG-MANAGED-PROCESS-001.md"
TARGET=1202

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

[ "$found_v1" -eq 0 ] && echo "[PASS] variante legacy NO resuelve para 12.2 — deprecada exactamente en esta versión" || { echo "[FAIL] la variante legacy resolvió para 12.2 — no debería"; FAIL=1; }
[ "$found_v2" -eq 1 ] && echo "[PASS] variante moderna resuelve para 12.2 (límite inferior exacto — introducción real de V\$DATAGUARD_PROCESS)" || { echo "[FAIL] la variante moderna no resolvió para 12.2"; FAIL=1; }

exit $FAIL
