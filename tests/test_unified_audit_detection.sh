#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 68/27.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/security/unified-auditing/SKILL.md"
Q="$ROOT/queries/security/Q-SEC-UNIFIED-AUDIT-POLICIES-001.md"

grep -q "min_version: \"12.1\"" "$ROOT/compatibility/oracle-dictionary/views.yaml" | grep -q "AUDIT_UNIFIED_ENABLED_POLICIES" \
  || true
grep -A2 "AUDIT_UNIFIED_ENABLED_POLICIES:" "$ROOT/compatibility/oracle-dictionary/views.yaml" | grep -q '"12.1"' \
  && echo "[PASS] AUDIT_UNIFIED_ENABLED_POLICIES certificada 12.1+ en el dictionary" \
  || { echo "[FAIL] falta la certificación de versión"; FAIL=1; }

grep -q "UNSUPPORTED" "$S" && echo "[PASS] unified-auditing degrada a UNSUPPORTED en 10g/11g" || { echo "[FAIL] falta la degradación"; FAIL=1; }
[ -f "$Q" ] && echo "[PASS] Q-SEC-UNIFIED-AUDIT-POLICIES-001.md existe" || { echo "[FAIL] falta la query"; FAIL=1; }

exit $FAIL
