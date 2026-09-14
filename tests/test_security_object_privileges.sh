#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 66.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for q in Q-SEC-OBJECT-PRIVILEGES-001 Q-SEC-ROLE-OBJECT-PRIVILEGES-001; do
  Q="$ROOT/queries/security/$q.md"
  [ -f "$Q" ] && echo "[PASS] $q.md existe" || { echo "[FAIL] falta $q.md"; FAIL=1; }
done

grep -q "grantee != 'PUBLIC'" "$ROOT/queries/security/Q-SEC-OBJECT-PRIVILEGES-001.md" \
  && echo "[PASS] Q-SEC-OBJECT-PRIVILEGES-001 excluye PUBLIC" \
  || { echo "[FAIL] falta la exclusión de PUBLIC"; FAIL=1; }

exit $FAIL
