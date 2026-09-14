#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 66.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for q in Q-SEC-SYSTEM-PRIVILEGES-001 Q-SEC-ROLE-SYSTEM-PRIVILEGES-001; do
  Q="$ROOT/queries/security/$q.md"
  [ -f "$Q" ] && echo "[PASS] $q.md existe" || { echo "[FAIL] falta $q.md"; FAIL=1; continue; }
  block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$Q" 2>/dev/null)
  echo "$block" | grep -Eiq 'password|spare4' && { echo "[FAIL] $q selecciona credencial"; FAIL=1; } || echo "[PASS] $q no selecciona credencial"
done

grep -q "grantee != 'PUBLIC'" "$ROOT/queries/security/Q-SEC-SYSTEM-PRIVILEGES-001.md" \
  && echo "[PASS] Q-SEC-SYSTEM-PRIVILEGES-001 excluye PUBLIC (certificado por separado)" \
  || { echo "[FAIL] falta la exclusión de PUBLIC"; FAIL=1; }

exit $FAIL
