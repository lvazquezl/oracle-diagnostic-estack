#!/usr/bin/env bash
# PHASE 6 — FINAL PDB IDENTITY & PATCH-LEVEL RESOLVER HARDENING, # 17, # 22, # 25, # 39.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
source "$ROOT/scripts/lib/version.sh"

result=$(compare_oracle_versions "12.1.0.2" "12.2.0.1")
[ "$result" = "-1" ] && echo "[PASS] compare_oracle_versions(12.1.0.2, 12.2.0.1) = -1" || { echo "[FAIL] compare_oracle_versions(12.1.0.2, 12.2.0.1) = $result, esperado -1"; FAIL=1; }

# Ejemplo textual del prompt (# 22): min 12.1.0.2, max 23.0 -> 12.2.0.1 MATCH.
version_in_range "12.2.0.1" "12.1.0.2" "23.0" && echo "[PASS] 12.2.0.1 está dentro de [12.1.0.2, 23.0]" || { echo "[FAIL] 12.2.0.1 no resolvió dentro de [12.1.0.2, 23.0]"; FAIL=1; }

exit $FAIL
