#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 62.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
MANIFEST="$ROOT/agents/oracle-multitenant-analyst/manifest.yaml"
Q="$ROOT/queries/multitenant/Q-CDB-USERS-001.md"

grep -qiE "CREATE.*USER.*(común|common)" "$MANIFEST" && echo "[PASS] manifest prohíbe creación de usuarios comunes" || { echo "[FAIL] falta la prohibición de creación de usuarios comunes"; FAIL=1; }

grep -qiE "^\s*SELECT" "$Q" && ! grep -qiE "^\s*CREATE USER" "$Q" && echo "[PASS] Q-CDB-USERS-001 es sólo lectura sobre CDB_USERS" || { echo "[FAIL] Q-CDB-USERS-001 no es puramente de sólo lectura"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Ninguna capacidad real de CREATE USER C##..."

exit $FAIL
