#!/usr/bin/env bash
# PHASE 6 — QUERY COMPATIBILITY & DICTIONARY CERTIFICATION HARDENING, # 28.
# Unit test del mecanismo de comparación patch-level-aware en sí mismo — no ligado a una query
# concreta (distinto de test_pdb_saved_state_12101_not_supported.sh, que sí lo está).
# 12.1.0.1 debe ser menor que 12.1.0.2.
#
# PHASE 6 — VERSION RESOLVER CONSOLIDATION FINALIZATION (# 6, # 12 del prompt): usa
# scripts/lib/version.sh (compare_oracle_versions) en vez de un vernum3() local.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/version.sh"
FAIL=0

result=$(compare_oracle_versions "12.1.0.1" "12.1.0.2")
[ "$result" = "-1" ] && echo "[PASS] compare_oracle_versions(12.1.0.1, 12.1.0.2) = -1" || { echo "[FAIL] compare_oracle_versions(12.1.0.1, 12.1.0.2) = $result, esperado -1"; FAIL=1; }

if version_gte "12.1.0.1" "12.1.0.2"; then
  echo "[FAIL] 12.1.0.1 se resolvería incorrectamente como >= 12.1.0.2"
  FAIL=1
else
  echo "[PASS] 12.1.0.1 correctamente < min declarado 12.1.0.2 — status esperado: UNSUPPORTED"
fi

exit $FAIL
