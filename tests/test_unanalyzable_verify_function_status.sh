#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 67/18.
# Sin lógica determinista -> VERIFY_FUNCTION_NOT_ANALYZABLE, nunca se asume compliance.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
FX="$ROOT/tests/fixtures/19c-custom-verify-function-partially-analyzable.yaml"
S="$ROOT/skills/security/password-verify-function/SKILL.md"

[ -f "$FX" ] && echo "[PASS] fixture de verify function no analizable existe" || { echo "[FAIL] falta la fixture"; FAIL=1; }
grep -q "VERIFY_FUNCTION_NOT_ANALYZABLE" "$S" && echo "[PASS] SKILL.md declara VERIFY_FUNCTION_NOT_ANALYZABLE" || { echo "[FAIL] falta el estado"; FAIL=1; }
grep -qi "compliance por mera presencia de la función" "$S" \
  && echo "[PASS] declara explícitamente que nunca asume compliance por presencia" \
  || { echo "[FAIL] falta la declaración"; FAIL=1; }

exit $FAIL
