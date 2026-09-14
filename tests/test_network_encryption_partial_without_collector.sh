#!/usr/bin/env bash
# PHASE 8 — SECURITY QUERY COMPATIBILITY, ORACLE NET EVIDENCE & STATIC VALIDATOR HARDENING,
# sección 30/37. Sin collector runtime certificado, el modelo debe producir PARTIALLY_SUPPORTED
# con evidence_source: MANUAL_SANITIZED_ORACLE_NET_CONFIGURATION — nunca fingir SUPPORTED.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/network/oracle-net-security/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }

grep -qi 'PARTIALLY_SUPPORTED' "$S" \
  && echo "[PASS] SKILL.md documenta el estado PARTIALLY_SUPPORTED" \
  || { echo "[FAIL] falta PARTIALLY_SUPPORTED"; FAIL=1; }

grep -qi 'MANUAL_SANITIZED_ORACLE_NET_CONFIGURATION' "$S" \
  && echo "[PASS] SKILL.md documenta evidence_source: MANUAL_SANITIZED_ORACLE_NET_CONFIGURATION" \
  || { echo "[FAIL] falta evidence_source MANUAL_SANITIZED_ORACLE_NET_CONFIGURATION"; FAIL=1; }

grep -qi 'nunca se finge.*SUPPORTED\|nunca.*SUPPORTED.*fingid' "$S" \
  && echo "[PASS] SKILL.md prohíbe explícitamente fingir SUPPORTED sin collector" \
  || { echo "[FAIL] falta la prohibición explícita de fingir SUPPORTED"; FAIL=1; }

grep -q 'capability_status: SUPPORTED|PARTIALLY_SUPPORTED|INSUFFICIENT_EVIDENCE' "$S" \
  && echo "[PASS] Output schema declara capability_status con los tres estados esperados" \
  || { echo "[FAIL] falta el output schema con capability_status"; FAIL=1; }

exit $FAIL
