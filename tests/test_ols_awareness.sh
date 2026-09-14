#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 70/40.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/security/ols-awareness/SKILL.md"
Q="$ROOT/queries/security/Q-SEC-OLS-STATUS-001.md"

grep -qi "Oracle Label Security" "$Q" && echo "[PASS] query usa el string exacto 'Oracle Label Security'" || { echo "[FAIL] falta el string exacto"; FAIL=1; }
grep -qi "nunca crea/modifica" "$S" && echo "[PASS] declara nunca crea/modifica policies/labels" || { echo "[FAIL] falta la declaración"; FAIL=1; }

exit $FAIL
