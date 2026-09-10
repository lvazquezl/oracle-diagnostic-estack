#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 62.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
MANIFEST="$ROOT/agents/oracle-multitenant-analyst/manifest.yaml"
Q="$ROOT/queries/multitenant/Q-CDB-USERS-001.md"

grep -qiE "CREATE.*USER.*(local|común o local)" "$MANIFEST" && echo "[PASS] manifest prohíbe creación de usuarios locales" || { echo "[FAIL] falta la prohibición de creación de usuarios locales"; FAIL=1; }

grep -qiE "^\s*SELECT" "$Q" && ! grep -qiE "^\s*CREATE USER" "$Q" && echo "[PASS] Q-CDB-USERS-001 es sólo lectura, ninguna PDB local user es creada" || { echo "[FAIL] Q-CDB-USERS-001 no es puramente de sólo lectura"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Ninguna capacidad real de CREATE USER local en una PDB"

exit $FAIL
