#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 67/16.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/security/password-complexity/SKILL.md"

grep -q "uppercase_min\|uppercase_requirement\|uppercase_status" "$S" && echo "[PASS] password-complexity evalúa uppercase" || { echo "[FAIL] falta evaluación de uppercase"; FAIL=1; }
grep -qi "REGEXP_LIKE.*A-Z\|mayúscula" "$ROOT/skills/security/password-verify-function/SKILL.md" \
  && echo "[PASS] password-verify-function documenta el patrón de detección de mayúscula" \
  || { echo "[FAIL] falta el patrón de detección"; FAIL=1; }

exit $FAIL
