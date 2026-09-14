#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 70/39.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/security/database-vault-awareness/SKILL.md"
Q="$ROOT/queries/security/Q-SEC-DATABASE-VAULT-STATUS-001.md"

grep -q "installed" "$S" && grep -q "enabled" "$S" && grep -q "status" "$S" \
  && echo "[PASS] declara installed/enabled/status" || { echo "[FAIL] falta installed/enabled/status"; FAIL=1; }
grep -qi "Oracle Database Vault" "$Q" && echo "[PASS] query usa el string exacto 'Oracle Database Vault'" || { echo "[FAIL] falta el string exacto"; FAIL=1; }
grep -q "nunca modifica" "$S" && echo "[PASS] declara nunca modifica" || { echo "[FAIL] falta la declaración de no-modificación"; FAIL=1; }

exit $FAIL
