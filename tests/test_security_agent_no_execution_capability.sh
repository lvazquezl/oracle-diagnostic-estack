#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 3.
# El agente no debe declarar ninguna capacidad de create/alter/drop users, grant/revoke, alter
# roles, change profiles, reset passwords, test passwords, retrieve hashes, crack/guess
# passwords, enable/disable audit, open/close wallets, rotate keys, change sqlnet/listener
# config, enable Database Vault, modify redaction/masking, execute DDL/DCL.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
AGENT="$ROOT/agents/oracle-security-analyst/AGENT.md"

for phrase in "create/alter/drop" "GRANT.*REVOKE" "resetea|prueba|adivina|crackea" "abre/cierra wallets" "rota claves" "habilita Database Vault" "ejecuta DDL/DCL"; do
  grep -qiE "$phrase" "$AGENT" && echo "[PASS] AGENT.md declara boundary: $phrase" || { echo "[FAIL] falta boundary: $phrase"; FAIL=1; }
done

exit $FAIL
