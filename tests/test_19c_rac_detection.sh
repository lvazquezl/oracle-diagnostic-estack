#!/usr/bin/env bash
# Valida el caso 19c RAC CDB: fixture existe con 3 instancias, capabilities.rac=SUPPORTED.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
FX="$ROOT/tests/fixtures/19c-rac-cdb.yaml"

[ -f "$FX" ] || { echo "[FAIL] falta fixture 19c-rac-cdb.yaml"; FAIL=1; }
grep -q 'cluster_mode: rac' "$FX" 2>/dev/null && echo "[PASS] fixture declara cluster_mode=rac" || { echo "[FAIL] fixture no declara rac"; FAIL=1; }
grep -q 'instance_count: 3' "$FX" 2>/dev/null && echo "[PASS] fixture declara 3 instancias" || { echo "[FAIL] fixture no declara instance_count=3"; FAIL=1; }
grep -q 'rac: SUPPORTED' "$FX" 2>/dev/null && echo "[PASS] fixture declara capabilities.rac=SUPPORTED (19c está dentro de cobertura certificada)" || { echo "[FAIL] fixture no declara rac SUPPORTED"; FAIL=1; }

exit $FAIL
