#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 67/17-18.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
FX="$ROOT/tests/fixtures/19c-custom-verify-function-compliant.yaml"

[ -f "$FX" ] && echo "[PASS] fixture de verify function custom compliant existe" || { echo "[FAIL] falta la fixture"; FAIL=1; }
grep -q "analyzable: true\|analyzable" "$ROOT/skills/security/password-verify-function/SKILL.md" \
  && echo "[PASS] SKILL.md declara el campo analyzable" || { echo "[FAIL] falta analyzable"; FAIL=1; }
grep -qi "username_similarity_check" "$ROOT/skills/security/password-verify-function/SKILL.md" \
  && echo "[PASS] declara username_similarity_check" || { echo "[FAIL] falta username_similarity_check"; FAIL=1; }

exit $FAIL
