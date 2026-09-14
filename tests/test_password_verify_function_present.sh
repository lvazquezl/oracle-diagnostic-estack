#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 67/17.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/security/password-verify-function/SKILL.md"

grep -q "configured: false" "$S" && echo "[PASS] declara configured: false cuando PASSWORD_VERIFY_FUNCTION es NULL" || { echo "[FAIL] falta el caso NULL"; FAIL=1; }
grep -q "PROFILE.*PASSWORD_VERIFY_FUNCTION.*identify function" "$S" \
  && echo "[PASS] documenta el flujo PROFILE -> PASSWORD_VERIFY_FUNCTION -> identify function" \
  || { echo "[FAIL] falta el flujo documentado"; FAIL=1; }

exit $FAIL
