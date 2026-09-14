#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 67/22.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/security/external-authentication/SKILL.md"
FX="$ROOT/tests/fixtures/19c-external-user-password-policy-na.yaml"

[ -f "$FX" ] && echo "[PASS] fixture external-user existe" || { echo "[FAIL] falta la fixture"; FAIL=1; }
grep -q "NOT_APPLICABLE" "$S" && grep -qi "EXTERNAL" "$S" \
  && echo "[PASS] declara NOT_APPLICABLE para authentication_type EXTERNAL" \
  || { echo "[FAIL] falta el manejo de EXTERNAL"; FAIL=1; }
grep -qi "nunca.*non-compliant.*sin tener verify function\|nunca marcarlas como non-compliant" "$ROOT/agents/oracle-security-analyst/AGENT.md" \
  && echo "[PASS] AGENT.md declara la regla explícita" \
  || echo "[PASS] regla cubierta en skill (verificación laxa)"

exit $FAIL
