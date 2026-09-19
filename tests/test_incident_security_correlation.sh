#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: incident/security-correlation nunca
# desbloquea cuentas ni modifica políticas — sólo diagnostica, usando el fixture de account-lockout.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/incident/security-correlation/SKILL.md"
FIXTURE="$ROOT/tests/fixtures/incident/security/account-lockout.txt"

[ -f "$FIXTURE" ] || { echo "[FAIL] falta el fixture $FIXTURE"; FAIL=1; }

grep -qi 'oracle-security-analyst' "$SKILL" \
  && echo "[PASS] referencia a oracle-security-analyst presente" \
  || { echo "[FAIL] falta la referencia a oracle-security-analyst"; FAIL=1; }

tr '\n' ' ' < "$SKILL" | grep -qiE 'Nunca desbloquea cuentas ni[[:space:]]*modifica' \
  && echo "[PASS] declara que nunca desbloquea cuentas ni modifica políticas" \
  || { echo "[FAIL] falta la prohibición de desbloqueo/modificación"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] incident/security-correlation consistente con el fixture de lockout"
exit $FAIL
