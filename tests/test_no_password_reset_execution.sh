#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 67/72/74.
# Toda recomendación de PASSWORD RESET/ALTER USER aparece exclusivamente como MANUAL DBA ACTION
# con execution_status: NOT_EXECUTED — nunca ejecutada.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
MANIFEST="$ROOT/agents/oracle-security-analyst/manifest.yaml"
SKILL="$ROOT/skills/security/manual-remediation-plan/SKILL.md"

grep -qi "ALTER USER.*IDENTIFIED BY.*password reset" "$MANIFEST" \
  && echo "[PASS] manifest prohíbe ALTER USER IDENTIFIED BY / password reset" \
  || { echo "[FAIL] falta la prohibición explícita"; FAIL=1; }

grep -q "execution_status: NOT_EXECUTED" "$SKILL" \
  && echo "[PASS] manual-remediation-plan fija execution_status: NOT_EXECUTED" \
  || { echo "[FAIL] falta execution_status: NOT_EXECUTED"; FAIL=1; }

grep -qi "PASSWORD RESET" "$SKILL" && grep -qi "MANUAL DBA ACTION" "$SKILL" \
  && echo "[PASS] PASSWORD RESET declarado exclusivamente como MANUAL DBA ACTION" \
  || { echo "[FAIL] falta la declaración de PASSWORD RESET como acción manual"; FAIL=1; }

exit $FAIL
