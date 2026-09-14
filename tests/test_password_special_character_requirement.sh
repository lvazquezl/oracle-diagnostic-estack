#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 67/16.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/security/password-complexity/SKILL.md"

grep -q "special_characters_min\|special_character_requirement\|special_character_status" "$S" \
  && echo "[PASS] password-complexity evalúa special character" || { echo "[FAIL] falta evaluación de special character"; FAIL=1; }
grep -qi "REGEXP_LIKE.*A-Za-z0-9\|(especial)" "$ROOT/skills/security/password-verify-function/SKILL.md" \
  && echo "[PASS] password-verify-function documenta el patrón de detección de carácter especial" \
  || { echo "[FAIL] falta el patrón de detección"; FAIL=1; }

exit $FAIL
