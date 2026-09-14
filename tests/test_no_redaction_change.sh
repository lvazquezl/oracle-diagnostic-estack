#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 72.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
MANIFEST="$ROOT/agents/oracle-security-analyst/manifest.yaml"

grep -qi "crear/alterar/eliminar Data Redaction policies" "$MANIFEST" \
  && echo "[PASS] manifest prohíbe crear/alterar/eliminar políticas de Data Redaction" \
  || { echo "[FAIL] falta la prohibición"; FAIL=1; }

for f in $(find "$ROOT/queries/security" -name 'Q-*.md' 2>/dev/null); do
  block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$f")
  if echo "$block" | grep -qiE 'DBMS_REDACT\.(ADD_POLICY|ALTER_POLICY|DROP_POLICY)'; then
    echo "[FAIL] $f (query certificada) invoca DBMS_REDACT de escritura"
    FAIL=1
  fi
done
[ $FAIL -eq 0 ] && echo "[PASS] Ninguna query certificada de Security modifica políticas de Data Redaction"

exit $FAIL
