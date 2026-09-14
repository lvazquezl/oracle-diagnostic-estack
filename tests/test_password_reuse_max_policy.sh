#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 67/16.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/security/password-policy-strength/SKILL.md"
Q="$ROOT/queries/security/Q-SEC-PASSWORD-PROFILES-001.md"

grep -q "reuse_max_policy\|PASSWORD_REUSE_MAX" "$S" && echo "[PASS] evalúa reuse_max_policy" || { echo "[FAIL] falta evaluación"; FAIL=1; }
grep -q "PASSWORD_REUSE_MAX" "$Q" && echo "[PASS] Q-SEC-PASSWORD-PROFILES-001 selecciona PASSWORD_REUSE_MAX" || { echo "[FAIL] falta la columna"; FAIL=1; }

exit $FAIL
