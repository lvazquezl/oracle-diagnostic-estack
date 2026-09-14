#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 70/43.
# Sin confirmación explícita del DBA, ninguna feature avanzada se reporta INCLUDED.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/security/licensing-gates/SKILL.md"
FX="$ROOT/tests/fixtures/19c-database-vault-awareness.yaml"

grep -qi "nunca.*INCLUDED.*sin confirmación" "$S" \
  && echo "[PASS] declara explícitamente que nunca INCLUDED sin confirmación" \
  || { echo "[FAIL] falta la declaración"; FAIL=1; }

grep -q "REQUIRES_REVIEW" "$FX" \
  && echo "[PASS] fixture database-vault-awareness confirma REQUIRES_REVIEW sin licensing_profile" \
  || { echo "[FAIL] la fixture no referencia REQUIRES_REVIEW"; FAIL=1; }

exit $FAIL
