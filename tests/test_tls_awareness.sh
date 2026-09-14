#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 69/35.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/security/tls-awareness/SKILL.md"
FX="$ROOT/tests/fixtures/19c-tcps-configured.yaml"

tr '\n' ' ' < "$S" | grep -qi "nunca[[:space:]]*realiza handshake activo a PROD" \
  && echo "[PASS] declara explícitamente que nunca hace handshake activo sin collector aprobado" \
  || { echo "[FAIL] falta la declaración"; FAIL=1; }
[ -f "$FX" ] && echo "[PASS] fixture tcps-configured existe" || { echo "[FAIL] falta la fixture"; FAIL=1; }

exit $FAIL
