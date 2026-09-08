#!/usr/bin/env bash
# PHASE 5 — DATA GUARD FINAL PROCESS-VIEW & PORTABILITY HARDENING, sección 10-11.
# Sobre 11g genérico (representado como 1102, alineado con tests/test_query_variant_resolver_11g.sh)
# sólo la variante legacy debe resolver — V$DATAGUARD_PROCESS no existe antes de 12.2.0.1
# (corregido: el hardening anterior asumía incorrectamente 11.2).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/dataguard/Q-DG-MANAGED-PROCESS-001.md"
TARGET=1102

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

[ "$found_v1" -eq 1 ] && echo "[PASS] variante legacy (10.2-12.1) resuelve para 11g (1102)" || { echo "[FAIL] variante legacy no resuelve para 11g"; FAIL=1; }
[ "$found_v2" -eq 0 ] && echo "[PASS] variante moderna NO resuelve para 11g (1102) — V\$DATAGUARD_PROCESS no existe antes de 12.2.0.1, sin fallback silencioso (# 10)" || { echo "[FAIL] la variante moderna resolvió para 11g — no debería, la vista no existe en esa versión"; FAIL=1; }

exit $FAIL
