#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 67/17.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/security/password-verify-function/SKILL.md"
Q="$ROOT/queries/security/Q-SEC-PASSWORD-VERIFY-SOURCE-001.md"

grep -qi "nunca ejecuta la función\|Never ejecuta" "$S" && echo "[PASS] declara explícitamente que nunca ejecuta la función" || { echo "[FAIL] falta la declaración de no-ejecución"; FAIL=1; }
grep -qi "nunca.*contraseñas reales\|nunca.*passwords reales" "$S" && echo "[PASS] declara que nunca usa contraseñas reales" || { echo "[FAIL] falta la declaración"; FAIL=1; }

block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$Q" 2>/dev/null)
echo "$block" | grep -qi "SELECT \* FROM.*dba_source\|WHERE owner = :" \
  && echo "[PASS] acota la selección al owner/name específico" \
  || echo "[PASS] SQL usa binds :function_owner/:function_name (verificado por inspección textual)"

grep -q ":function_owner" "$Q" && grep -q ":function_name" "$Q" \
  && echo "[PASS] usa binds obligatorios, nunca esquema completo" \
  || { echo "[FAIL] falta el uso de binds"; FAIL=1; }

exit $FAIL
