#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 66.
# security/roles debe consumir direct + nested role grants — nunca sólo grants directos.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
M="$ROOT/skills/security/roles/manifest.yaml"

for q in Q-SEC-ROLES-001 Q-SEC-ROLE-GRANTS-001 Q-SEC-NESTED-ROLE-GRANTS-001; do
  grep -q "$q" "$M" && echo "[PASS] roles consume $q" || { echo "[FAIL] roles no consume $q"; FAIL=1; }
done

for q in Q-SEC-ROLES-001 Q-SEC-ROLE-GRANTS-001 Q-SEC-NESTED-ROLE-GRANTS-001; do
  [ -f "$ROOT/queries/security/$q.md" ] && echo "[PASS] $q.md existe" || { echo "[FAIL] falta $q.md"; FAIL=1; }
done

exit $FAIL
