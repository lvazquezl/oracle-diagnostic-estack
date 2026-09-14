#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 70/42.
# Data Masking and Subsetting (EM Pack) y Data Redaction (ASO) son licenciamientos distintos —
# nunca se asume el mismo.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/security/data-masking-awareness/SKILL.md"

grep -q "Enterprise Manager Pack" "$S" && echo "[PASS] identifica Data Masking como Enterprise Manager Pack" || { echo "[FAIL] falta la identificación"; FAIL=1; }
grep -qi "nunca.*mismo\|licenciamientos distintos" "$S" \
  && echo "[PASS] declara explícitamente que son licenciamientos distintos" \
  || { echo "[FAIL] falta la declaración de distinción"; FAIL=1; }
grep -qi "nunca ejecuta jobs de Data Masking" "$S" && echo "[PASS] declara nunca ejecutar masking" || { echo "[FAIL] falta la declaración"; FAIL=1; }

exit $FAIL
