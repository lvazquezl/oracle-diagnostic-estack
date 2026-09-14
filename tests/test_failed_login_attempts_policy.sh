#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 67/16.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/security/password-policy-strength/SKILL.md"
Q="$ROOT/queries/security/Q-SEC-PASSWORD-PROFILES-001.md"

grep -q "failed_login_policy\|FAILED_LOGIN_ATTEMPTS" "$S" && echo "[PASS] evalúa failed_login_policy" || { echo "[FAIL] falta evaluación"; FAIL=1; }
grep -q "FAILED_LOGIN_ATTEMPTS" "$Q" && echo "[PASS] Q-SEC-PASSWORD-PROFILES-001 selecciona FAILED_LOGIN_ATTEMPTS" || { echo "[FAIL] falta la columna"; FAIL=1; }

exit $FAIL
