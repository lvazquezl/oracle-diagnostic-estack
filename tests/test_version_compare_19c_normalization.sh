#!/usr/bin/env bash
# PHASE 6 — FINAL PDB IDENTITY & PATCH-LEVEL RESOLVER HARDENING, # 18-19, # 25.
# 19c, 19.27, 19.27.0.0.0 deben normalizar de forma consistente con el alias de marketing y con
# strings de patch-level completos (# 18 del prompt: formatos comunes soportados).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
source "$ROOT/scripts/lib/version.sh"

n19c=$(normalize_oracle_version "19c")
[ "$n19c" = "19 0 0 0 0" ] && echo "[PASS] normalize_oracle_version(19c) = 19 0 0 0 0" || { echo "[FAIL] normalize_oracle_version(19c) = '$n19c'"; FAIL=1; }

version_gte "19.27" "19c" && echo "[PASS] 19.27 >= 19c (el alias de marketing es el piso de la familia)" || { echo "[FAIL] 19.27 no resolvió >= 19c"; FAIL=1; }

result=$(compare_oracle_versions "19.3.0.0" "19.27.0.0.0")
[ "$result" = "-1" ] && echo "[PASS] 19.3.0.0 < 19.27.0.0.0 (comparación numérica, no lexicográfica — # 17 del prompt)" || { echo "[FAIL] compare_oracle_versions(19.3.0.0, 19.27.0.0.0) = $result, esperado -1"; FAIL=1; }

exit $FAIL
