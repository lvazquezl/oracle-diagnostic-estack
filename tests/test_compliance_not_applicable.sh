#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 71/45.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/security/compliance-mapping/SKILL.md"

grep -q "NOT_APPLICABLE" "$S" && grep -q "NOT_ASSESSED" "$S" \
  && echo "[PASS] distingue NOT_APPLICABLE de NOT_ASSESSED" \
  || { echo "[FAIL] falta la distinción NOT_APPLICABLE/NOT_ASSESSED"; FAIL=1; }
grep -qi "no debe confundirse con .FAIL.\|no debe confundirse con FAIL" "$S" \
  && echo "[PASS] declara explícitamente que NOT_ASSESSED no debe confundirse con FAIL" \
  || { echo "[FAIL] falta la aclaración"; FAIL=1; }

exit $FAIL
