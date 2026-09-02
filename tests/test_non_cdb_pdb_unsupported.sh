#!/usr/bin/env bash
# Valida que multitenant/pdb no aplique fuera de CDB (NON_CDB -> UNSUPPORTED).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

if grep -q 'NON-CDB              → multitenant/pdb  → UNSUPPORTED' "$ROOT/policies/version-awareness-policy.md"; then
  echo "[PASS] policies/version-awareness-policy.md documenta NON-CDB -> multitenant/pdb -> UNSUPPORTED"
else
  echo "[FAIL] policies/version-awareness-policy.md no documenta NON-CDB -> multitenant/pdb -> UNSUPPORTED"
  FAIL=1
fi

if grep -q 'container_scope: CDB_ROOT' "$ROOT/queries/Q-PERF-WAIT-AWR-001.md" || grep -rq 'container_scope: CDB_ROOT' "$ROOT/queries"; then
  echo "[PASS] Existen queries certificadas con container_scope: CDB_ROOT (no aplican a NON_CDB por diseño)"
else
  echo "[FAIL] Ninguna query certificada declara container_scope: CDB_ROOT"
  FAIL=1
fi

if grep -q 'CDB/PDB exclusivamente' "$ROOT/agents/oracle-multitenant-analyst.md"; then
  echo "[PASS] oracle-multitenant-analyst.md declara alcance exclusivo CDB/PDB (no aplica a NON-CDB)"
else
  echo "[FAIL] oracle-multitenant-analyst.md no declara exclusión explícita de NON-CDB"
  FAIL=1
fi

exit $FAIL
