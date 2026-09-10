#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 31/61.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/multitenant/Q-CDB-RESOURCE-MANAGER-001.md"

[ -f "$Q" ] || { echo "[FAIL] falta Q-CDB-RESOURCE-MANAGER-001.md"; exit 1; }
grep -qi "dba_cdb_rsrc_plan_directives" "$Q" && echo "[PASS] usa el nombre real DBA_CDB_RSRC_PLAN_DIRECTIVES" || { echo "[FAIL] falta el nombre correcto de la vista"; FAIL=1; }
grep -qi "shares" "$Q" && grep -qi "utilization_limit" "$Q" && grep -qi "parallel_server_limit" "$Q" && echo "[PASS] selecciona shares/utilization_limit/parallel_server_limit" || { echo "[FAIL] faltan columnas de directiva"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Resource Manager visibility implementado con la vista real correcta"

exit $FAIL
