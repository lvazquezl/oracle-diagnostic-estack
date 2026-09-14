#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 69/72.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
MANIFEST="$ROOT/agents/oracle-security-analyst/manifest.yaml"

grep -qi "modificar SQLNET.ENCRYPTION_\*/SQLNET.CRYPTO_CHECKSUM_\*/listener.ora/sqlnet.ora" "$MANIFEST" \
  && echo "[PASS] manifest prohíbe modificar sqlnet.ora/listener.ora" \
  || { echo "[FAIL] falta la prohibición explícita"; FAIL=1; }

for f in $(find "$ROOT/skills/security" "$ROOT/queries/security" -type f 2>/dev/null); do
  if grep -qiE '^\s*(ALTER SYSTEM SET sqlnet|edit listener\.ora|edit sqlnet\.ora)' "$f"; then
    echo "[FAIL] $f contiene una capacidad de edición de configuración de red"
    FAIL=1
  fi
done
[ $FAIL -eq 0 ] && echo "[PASS] Ninguna capacidad de editar configuración de red en el dominio Security"

exit $FAIL
