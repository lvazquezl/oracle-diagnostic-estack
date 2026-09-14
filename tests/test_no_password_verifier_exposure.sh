#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 67/25-26.
# password_versions se normaliza a un enum — nunca se expone la cadena cruda de Oracle como verifier.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/security/password-verifiers/SKILL.md"
SCHEMA="$ROOT/agents/oracle-security-analyst/output-schema.yaml"

grep -qi "nunca.*muestra.*PASSWORD.*SPARE4\|nunca expone.*password.*verifier" "$S" \
  && echo "[PASS] password-verifiers declara explícitamente que nunca expone PASSWORD/SPARE4/verifier" \
  || { echo "[FAIL] falta la declaración explícita"; FAIL=1; }

grep -q "verifier_posture: LEGACY_PRESENT|MODERN_PRESENT|MIXED|UNKNOWN" "$SCHEMA" \
  && echo "[PASS] output-schema sólo expone el enum normalizado, nunca el valor crudo" \
  || { echo "[FAIL] falta el enum normalizado en el schema"; FAIL=1; }

exit $FAIL
