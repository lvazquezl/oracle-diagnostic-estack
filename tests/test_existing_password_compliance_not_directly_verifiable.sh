#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 67/21.
# Obligatorio: aunque policy_status sea COMPLIANT, existing_password_compliance siempre
# NOT_DIRECTLY_VERIFIABLE.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SCHEMA="$ROOT/agents/oracle-security-analyst/output-schema.yaml"
S="$ROOT/skills/security/password-policy-strength/SKILL.md"
FX="$ROOT/tests/fixtures/19c-password-policy-compliant.yaml"

grep -q "existing_password_compliance: NOT_DIRECTLY_VERIFIABLE" "$SCHEMA" \
  && echo "[PASS] output-schema fija existing_password_compliance a NOT_DIRECTLY_VERIFIABLE (sin variantes)" \
  || { echo "[FAIL] falta el campo fijo en el schema"; FAIL=1; }

grep -qi "obligatorio, no opcional" "$S" \
  && echo "[PASS] SKILL.md declara la regla como obligatoria" \
  || { echo "[FAIL] falta la declaración de obligatoriedad"; FAIL=1; }

grep -q "NOT_DIRECTLY_VERIFIABLE" "$FX" \
  && echo "[PASS] fixture de policy compliant también verifica NOT_DIRECTLY_VERIFIABLE" \
  || { echo "[FAIL] la fixture no referencia NOT_DIRECTLY_VERIFIABLE"; FAIL=1; }

exit $FAIL
