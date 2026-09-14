#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 70/41.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/security/data-redaction-awareness/SKILL.md"
Q="$ROOT/queries/security/Q-SEC-DATA-REDACTION-POLICIES-001.md"

grep -q "Advanced Security Option" "$S" && echo "[PASS] declara licenciamiento Advanced Security Option" || { echo "[FAIL] falta el licenciamiento"; FAIL=1; }
grep -q "REDACTION_POLICIES" "$Q" && grep -q "REDACTION_COLUMNS" "$Q" \
  && echo "[PASS] query consulta REDACTION_POLICIES/REDACTION_COLUMNS" || { echo "[FAIL] faltan las vistas"; FAIL=1; }
grep -q "SELECT_CATALOG_ROLE" "$Q" && echo "[PASS] documenta el privilegio SELECT_CATALOG_ROLE requerido" || { echo "[FAIL] falta SELECT_CATALOG_ROLE"; FAIL=1; }

exit $FAIL
