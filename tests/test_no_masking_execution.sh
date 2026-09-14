#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 72.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
MANIFEST="$ROOT/agents/oracle-security-analyst/manifest.yaml"

grep -qi "ejecutar Data Masking/Subsetting jobs" "$MANIFEST" \
  && echo "[PASS] manifest prohíbe ejecutar jobs de Data Masking/Subsetting" \
  || { echo "[FAIL] falta la prohibición"; FAIL=1; }

grep -qi "nunca ejecuta jobs de Data Masking" "$ROOT/skills/security/data-masking-awareness/SKILL.md" \
  && echo "[PASS] data-masking-awareness declara nunca ejecutar masking" \
  || { echo "[FAIL] falta la declaración en el skill"; FAIL=1; }

exit $FAIL
