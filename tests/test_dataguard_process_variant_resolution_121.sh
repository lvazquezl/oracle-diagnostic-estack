#!/usr/bin/env bash
# PHASE 5 — DATA GUARD FINAL PROCESS-VIEW & PORTABILITY HARDENING, sección 10-11.
# Sobre 12.1 (el límite superior exacto del rango legacy) sólo la variante legacy debe
# resolver — V$DATAGUARD_PROCESS todavía no existe (introducida en 12.2.0.1).
#
# PHASE 6 — VERSION RESOLVER CONSOLIDATION FINALIZATION (# 6, # 14 del prompt): usa
# scripts/lib/version.sh en vez de un vernum() local.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/version.sh"
FAIL=0
Q="$ROOT/queries/dataguard/Q-DG-MANAGED-PROCESS-001.md"
TARGET="12.1"

mins=$(grep -oE 'oracle_versions: \{min: "[0-9]+\.[0-9]+", max: "[0-9]+\.[0-9]+"' "$Q")
found_v1=0 found_v2=0
while IFS= read -r r; do
  mn=$(echo "$r" | grep -oE 'min: "[^"]+"' | grep -oE '"[^"]+"' | tr -d '"')
  mx=$(echo "$r" | grep -oE 'max: "[^"]+"' | grep -oE '"[^"]+"' | tr -d '"')
  if version_in_range "$TARGET" "$mn" "$mx"; then
    [ "$mn" = "10.2" ] && found_v1=1
    [ "$mn" = "12.2" ] && found_v2=1
  fi
done <<< "$mins"

[ "$found_v1" -eq 1 ] && echo "[PASS] variante legacy resuelve para 12.1 (límite superior exacto del rango legacy)" || { echo "[FAIL] la variante legacy no resolvió para 12.1"; FAIL=1; }
[ "$found_v2" -eq 0 ] && echo "[PASS] variante moderna NO resuelve para 12.1 — V\$DATAGUARD_PROCESS aún no existe" || { echo "[FAIL] la variante moderna resolvió para 12.1 — no debería"; FAIL=1; }

exit $FAIL
