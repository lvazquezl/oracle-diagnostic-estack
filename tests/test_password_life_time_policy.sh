#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 67/16.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/security/password-policy-strength/SKILL.md"
Q="$ROOT/queries/security/Q-SEC-PASSWORD-PROFILES-001.md"

grep -q "expiration_policy\|password_life_time" "$S" && echo "[PASS] evalúa expiration/password_life_time" || { echo "[FAIL] falta evaluación de expiration"; FAIL=1; }
grep -q "PASSWORD_LIFE_TIME" "$Q" && echo "[PASS] Q-SEC-PASSWORD-PROFILES-001 selecciona PASSWORD_LIFE_TIME" || { echo "[FAIL] falta PASSWORD_LIFE_TIME en la query"; FAIL=1; }

exit $FAIL
