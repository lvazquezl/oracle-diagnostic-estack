#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 68/29.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/security/privileged-audit/SKILL.md"

grep -qi "nunca inventa política corporativa" "$S" \
  && echo "[PASS] declara explícitamente que nunca inventa política corporativa" \
  || { echo "[FAIL] falta la declaración"; FAIL=1; }
grep -q "sys_operations_visible" "$S" && echo "[PASS] declara sys_operations_visible" || { echo "[FAIL] falta sys_operations_visible"; FAIL=1; }

exit $FAIL
