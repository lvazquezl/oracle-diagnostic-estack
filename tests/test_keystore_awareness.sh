#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 69/32.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/security/keystore-awareness/SKILL.md"
SCHEMA="$ROOT/agents/oracle-security-analyst/output-schema.yaml"
FX="$ROOT/tests/fixtures/19c-keystore-closed.yaml"

grep -q "secrets_exposed: false" "$S" && echo "[PASS] SKILL.md fija secrets_exposed a false" || { echo "[FAIL] falta secrets_exposed: false"; FAIL=1; }
grep -A1 "keystore:" "$SCHEMA" | grep -q "type:" || grep -q "secrets_exposed: false" "$SCHEMA" \
  && echo "[PASS] output-schema fija secrets_exposed: false (sin variantes de tipo)" \
  || { echo "[FAIL] falta secrets_exposed: false en el schema"; FAIL=1; }
[ -f "$FX" ] && echo "[PASS] fixture keystore-closed existe" || { echo "[FAIL] falta la fixture"; FAIL=1; }

exit $FAIL
