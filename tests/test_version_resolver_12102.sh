#!/usr/bin/env bash
# PHASE 6 — QUERY COMPATIBILITY & DICTIONARY CERTIFICATION HARDENING, # 28.
# Unit test del mecanismo de comparación patch-level-aware — 12.1.0.2 debe satisfacer un min
# declarado de 12.1.0.2 (igualdad inclusiva), y 12.1.0.3/12.2 deben seguir por encima.
#
# PHASE 6 — VERSION RESOLVER CONSOLIDATION FINALIZATION (# 6, # 12 del prompt): usa
# scripts/lib/version.sh (version_gte) en vez de un vernum3() local.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/version.sh"
FAIL=0

version_gte "12.1.0.2" "12.1.0.2" && echo "[PASS] 12.1.0.2 satisface min declarado 12.1.0.2 (igualdad inclusiva) — status esperado: SUPPORTED" || { echo "[FAIL] 12.1.0.2 no satisface su propio mínimo"; FAIL=1; }

version_gte "12.1.0.3" "12.1.0.2" && echo "[PASS] 12.1.0.3 >= min declarado 12.1.0.2" || { echo "[FAIL] 12.1.0.3 no resolvió como >= 12.1.0.2"; FAIL=1; }

version_gte "12.2" "12.1.0.2" && echo "[PASS] 12.2 >= min declarado 12.1.0.2" || { echo "[FAIL] 12.2 no resolvió como >= 12.1.0.2"; FAIL=1; }

exit $FAIL
