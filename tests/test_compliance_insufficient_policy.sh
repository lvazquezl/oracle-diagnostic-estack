#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 71/45.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/security/compliance-mapping/SKILL.md"

grep -q "INSUFFICIENT_POLICY" "$S" && echo "[PASS] declara INSUFFICIENT_POLICY" || { echo "[FAIL] falta INSUFFICIENT_POLICY"; FAIL=1; }
grep -qi "nunca .FAIL. en ese caso\|nunca FAIL en ese caso" "$S" \
  && echo "[PASS] declara que INSUFFICIENT_POLICY nunca se reporta como FAIL" \
  || { echo "[FAIL] falta la distinción explícita"; FAIL=1; }

exit $FAIL
