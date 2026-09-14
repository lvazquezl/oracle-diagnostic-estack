#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 66.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/security/account-status/SKILL.md"
M="$ROOT/skills/security/account-status/manifest.yaml"

[ -f "$S" ] && [ -f "$M" ] && echo "[PASS] security/account-status materializado" || { echo "[FAIL] security/account-status incompleto"; FAIL=1; }
grep -q "Q-SEC-ACCOUNT-INVENTORY-001" "$M" && echo "[PASS] account-status consume Q-SEC-ACCOUNT-INVENTORY-001" || { echo "[FAIL] account-status no declara su evidencia requerida"; FAIL=1; }

exit $FAIL
