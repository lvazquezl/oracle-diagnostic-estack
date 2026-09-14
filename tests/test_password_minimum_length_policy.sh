#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 67/16.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/security/password-policy-strength/SKILL.md"

grep -q "minimum_length" "$S" && echo "[PASS] password-policy-strength evalúa minimum_length" || { echo "[FAIL] falta minimum_length"; FAIL=1; }
grep -q "POLICY_NOT_DEFINED" "$S" && echo "[PASS] declara POLICY_NOT_DEFINED sin target" || { echo "[FAIL] falta POLICY_NOT_DEFINED"; FAIL=1; }

for fx in 19c-password-policy-compliant.yaml 19c-password-policy-non-compliant.yaml; do
  [ -f "$ROOT/tests/fixtures/$fx" ] && echo "[PASS] fixture $fx existe" || { echo "[FAIL] falta fixture $fx"; FAIL=1; }
done

exit $FAIL
