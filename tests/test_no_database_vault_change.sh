#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 72.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
MANIFEST="$ROOT/agents/oracle-security-analyst/manifest.yaml"

grep -qi "habilitar Database Vault, crear/modificar realms" "$MANIFEST" \
  && echo "[PASS] manifest prohíbe habilitar/modificar Database Vault" \
  || { echo "[FAIL] falta la prohibición"; FAIL=1; }

for f in $(find "$ROOT/queries/security" -name 'Q-*.md' 2>/dev/null); do
  block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$f")
  if echo "$block" | grep -qiE 'DBMS_MACADM|CREATE_REALM|CREATE_COMMAND_RULE'; then
    echo "[FAIL] $f (query certificada) contiene una llamada de escritura de Database Vault"
    FAIL=1
  fi
done
[ $FAIL -eq 0 ] && echo "[PASS] Ninguna query certificada de Security modifica Database Vault"

exit $FAIL
