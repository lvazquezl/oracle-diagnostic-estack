#!/usr/bin/env bash
# PHASE 6 — FINAL PDB IDENTITY & PATCH-LEVEL RESOLVER HARDENING, # 18-19, # 25.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
source "$ROOT/scripts/lib/version.sh"

n23ai=$(normalize_oracle_version "23ai")
[ "$n23ai" = "23 0 0 0 0" ] && echo "[PASS] normalize_oracle_version(23ai) = 23 0 0 0 0" || { echo "[FAIL] normalize_oracle_version(23ai) = '$n23ai'"; FAIL=1; }

n230=$(normalize_oracle_version "23.0")
[ "$n230" = "23 0 0 0 0" ] && echo "[PASS] normalize_oracle_version(23.0) = 23 0 0 0 0 (alias y forma numérica equivalentes)" || { echo "[FAIL] normalize_oracle_version(23.0) = '$n230'"; FAIL=1; }

result=$(compare_oracle_versions "23ai" "23.0")
[ "$result" = "0" ] && echo "[PASS] 23ai == 23.0" || { echo "[FAIL] compare_oracle_versions(23ai, 23.0) = $result, esperado 0"; FAIL=1; }

exit $FAIL
