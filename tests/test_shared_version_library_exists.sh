#!/usr/bin/env bash
# PHASE 6 — VERSION RESOLVER CONSOLIDATION FINALIZATION, # 4, # 28.
# Valida que scripts/lib/version.sh existe y expone las 5 funciones canónicas.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
LIB="$ROOT/scripts/lib/version.sh"

[ -f "$LIB" ] && echo "[PASS] scripts/lib/version.sh existe" || { echo "[FAIL] scripts/lib/version.sh no existe"; FAIL=1; exit 1; }

for fn in normalize_oracle_version compare_oracle_versions version_gte version_lte version_in_range; do
  grep -qE "^${fn}\s*\(\)" "$LIB" && echo "[PASS] scripts/lib/version.sh declara $fn" || { echo "[FAIL] scripts/lib/version.sh no declara $fn"; FAIL=1; }
done

# Sanity check funcional mínimo — la librería realmente funciona, no sólo declara los nombres.
source "$LIB"
[ "$(compare_oracle_versions "12.1" "12.2")" = "-1" ] && echo "[PASS] compare_oracle_versions funciona (12.1 < 12.2)" || { echo "[FAIL] compare_oracle_versions no produce el resultado esperado"; FAIL=1; }
version_in_range "19.0" "10.2" "23.0" && echo "[PASS] version_in_range funciona (19.0 dentro de [10.2, 23.0])" || { echo "[FAIL] version_in_range no produce el resultado esperado"; FAIL=1; }

exit $FAIL
