#!/usr/bin/env bash
# PHASE 6 — FINAL PDB IDENTITY & PATCH-LEVEL RESOLVER HARDENING, # 17, # 25, # 39.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
source "$ROOT/scripts/lib/version.sh"

result=$(compare_oracle_versions "12.1.0.1" "12.1.0.2")
[ "$result" = "-1" ] && echo "[PASS] compare_oracle_versions(12.1.0.1, 12.1.0.2) = -1" || { echo "[FAIL] compare_oracle_versions(12.1.0.1, 12.1.0.2) = $result, esperado -1"; FAIL=1; }

version_lte "12.1.0.1" "12.1.0.2" && echo "[PASS] version_lte(12.1.0.1, 12.1.0.2)" || { echo "[FAIL] version_lte(12.1.0.1, 12.1.0.2) falló"; FAIL=1; }
if version_gte "12.1.0.1" "12.1.0.2"; then echo "[FAIL] version_gte(12.1.0.1, 12.1.0.2) no debería ser cierto"; FAIL=1; else echo "[PASS] version_gte(12.1.0.1, 12.1.0.2) correctamente falso"; fi

exit $FAIL
