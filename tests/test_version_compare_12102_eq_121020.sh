#!/usr/bin/env bash
# PHASE 6 — FINAL PDB IDENTITY & PATCH-LEVEL RESOLVER HARDENING, # 17, # 25, # 39.
# 12.1.0.2 y 12.1.0.2.0 deben ser equivalentes — componente "revision" faltante rellenado con 0
# de forma determinista (# 17 del prompt: "no asumir que siempre habrá cinco componentes").
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
source "$ROOT/scripts/lib/version.sh"

result=$(compare_oracle_versions "12.1.0.2" "12.1.0.2.0")
[ "$result" = "0" ] && echo "[PASS] compare_oracle_versions(12.1.0.2, 12.1.0.2.0) = 0" || { echo "[FAIL] compare_oracle_versions(12.1.0.2, 12.1.0.2.0) = $result, esperado 0"; FAIL=1; }

version_gte "12.1.0.2.0" "12.1.0.2" && version_lte "12.1.0.2.0" "12.1.0.2" && echo "[PASS] 12.1.0.2.0 es simultáneamente >= y <= 12.1.0.2" || { echo "[FAIL] 12.1.0.2.0 no se comportó como equivalente a 12.1.0.2"; FAIL=1; }

exit $FAIL
