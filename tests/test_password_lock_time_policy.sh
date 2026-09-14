#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 67/16.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/security/password-policy-strength/SKILL.md"
Q="$ROOT/queries/security/Q-SEC-PASSWORD-PROFILES-001.md"

grep -q "lock_time_policy\|PASSWORD_LOCK_TIME" "$S" && echo "[PASS] evalúa lock_time_policy" || { echo "[FAIL] falta evaluación"; FAIL=1; }
grep -q "PASSWORD_LOCK_TIME" "$Q" && echo "[PASS] Q-SEC-PASSWORD-PROFILES-001 selecciona PASSWORD_LOCK_TIME" || { echo "[FAIL] falta la columna"; FAIL=1; }

exit $FAIL
