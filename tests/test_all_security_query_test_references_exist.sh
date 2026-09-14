#!/usr/bin/env bash
# PHASE 8 — SECURITY QUERY COMPATIBILITY, ORACLE NET EVIDENCE & STATIC VALIDATOR HARDENING,
# sección 39. Recorre todos los Query Contracts de queries/security/** y confirma que todo test
# referenciado en su frontmatter `tests: [...]` existe realmente bajo tests/ — esto habría
# detectado tests/test_security_default_accounts.sh faltante (referenciado por
# Q-SEC-DEFAULT-ACCOUNTS-001.md desde su creación en Fase 8, nunca materializado hasta este
# hardening).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
CHECKED=0

for f in "$ROOT"/queries/security/Q-*.md; do
  [ -f "$f" ] || continue
  raw=$(grep -oE '^tests: \[[^]]*\]' "$f" | head -1)
  [ -z "$raw" ] && continue
  list=$(echo "$raw" | sed -E 's/^tests: \[//; s/\]$//' | tr ',' '\n' | sed -E 's/^ *//; s/ *$//')
  while IFS= read -r t; do
    [ -z "$t" ] && continue
    CHECKED=$((CHECKED+1))
    if [ -f "$ROOT/$t" ]; then
      echo "[PASS] $(basename "$f") -> $t existe"
    else
      echo "[FAIL] $(basename "$f") referencia '$t' pero el archivo no existe"
      FAIL=1
    fi
  done <<< "$list"
done

if [ "$CHECKED" -lt 50 ]; then
  echo "[FAIL] sólo se verificaron $CHECKED referencias de test — se esperaban >= 50 (el catálogo Security tiene 30 queries)"
  FAIL=1
else
  echo "[PASS] se verificaron $CHECKED referencias de test en queries/security/**"
fi

exit $FAIL
