#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 66.
# Q-SEC-COMMON-LOCAL-USERS-001 debe ser CDB_ROOT_ONLY y nunca mezclar container scope.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/security/Q-SEC-COMMON-LOCAL-USERS-001.md"

grep -q "container_scope: CDB_ROOT_ONLY" "$Q" && echo "[PASS] Q-SEC-COMMON-LOCAL-USERS-001 declara CDB_ROOT_ONLY" || { echo "[FAIL] container_scope incorrecto"; FAIL=1; }

block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$Q" 2>/dev/null)
echo "$block" | grep -qi 'con_id' && echo "[PASS] selecciona con_id (requisito de distinción cross-container)" || { echo "[FAIL] no selecciona con_id"; FAIL=1; }

exit $FAIL
