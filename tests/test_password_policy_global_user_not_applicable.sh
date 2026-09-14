#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 67/22.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/security/external-authentication/SKILL.md"
FX="$ROOT/tests/fixtures/19c-global-user-password-policy-na.yaml"

[ -f "$FX" ] && echo "[PASS] fixture global-user existe" || { echo "[FAIL] falta la fixture"; FAIL=1; }
grep -q "NOT_APPLICABLE" "$S" && grep -qi "GLOBAL" "$S" \
  && echo "[PASS] declara NOT_APPLICABLE para authentication_type GLOBAL" \
  || { echo "[FAIL] falta el manejo de GLOBAL"; FAIL=1; }

exit $FAIL
