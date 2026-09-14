#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 67/16.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/security/password-complexity/SKILL.md"

grep -q "digits_min\|digit_requirement\|digit_status" "$S" && echo "[PASS] password-complexity evalúa digit" || { echo "[FAIL] falta evaluación de digit"; FAIL=1; }
grep -qi "REGEXP_LIKE.*0-9\|dígito" "$ROOT/skills/security/password-verify-function/SKILL.md" \
  && echo "[PASS] password-verify-function documenta el patrón de detección de dígito" \
  || { echo "[FAIL] falta el patrón de detección"; FAIL=1; }

exit $FAIL
