#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 8/57.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in "$ROOT"/queries/multitenant/Q-*.md; do
  grep -q "^supported_oracle_versions:" "$f" && echo "[PASS] $(basename "$f") declara supported_oracle_versions" || { echo "[FAIL] $(basename "$f") no declara supported_oracle_versions"; FAIL=1; }
done

[ $FAIL -eq 0 ] && echo "[PASS] Todas las queries Multitenant declaran compatibilidad de versión explícita"

exit $FAIL
