#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 67/26.
# Ninguna query/skill del dominio Security selecciona o expone password hash/SPARE4.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
PATTERN='\bpassword\b\s*,|spare4|password_hash'

for f in $(find "$ROOT/queries/security" -name 'Q-*.md' 2>/dev/null); do
  block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$f")
  if echo "$block" | grep -Eiq "$PATTERN"; then
    echo "[FAIL] $f parece seleccionar material de credencial"
    FAIL=1
  fi
done
[ $FAIL -eq 0 ] && echo "[PASS] Ninguna query Security selecciona password hashes ni material de credencial"

grep -q "password_hash_verifier_protection" "$ROOT/agents/oracle-security-analyst/output-schema.yaml" \
  && echo "[PASS] output-schema declara password_hash_verifier_protection" \
  || { echo "[FAIL] falta password_hash_verifier_protection en el schema"; FAIL=1; }

exit $FAIL
