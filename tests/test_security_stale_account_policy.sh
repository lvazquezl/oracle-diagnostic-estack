#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 68/9.
# Sin política/umbral explícito -> INSUFFICIENT_POLICY, nunca un umbral inventado.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/security/stale-accounts/SKILL.md"

grep -q "INSUFFICIENT_POLICY" "$S" && echo "[PASS] declara INSUFFICIENT_POLICY" || { echo "[FAIL] falta INSUFFICIENT_POLICY"; FAIL=1; }
grep -qi "nunca inventa un umbral" "$S" && echo "[PASS] declara explícitamente que nunca inventa umbral" || { echo "[FAIL] falta la declaración"; FAIL=1; }
# "90 días" sólo es aceptable como ejemplo negativo explícito ("nunca inventa un umbral como
# '90 días'") — nunca como un valor realmente usado por la lógica de decisión.
if grep -qi "90 días" "$S"; then
  grep -B1 -i "90 días" "$S" | grep -qiE "nunca|never|prohibid|forbidden" \
    && echo "[PASS] '90 días' aparece sólo como ejemplo negativo explícito, no como umbral real" \
    || { echo "[FAIL] '90 días' aparece sin contexto de prohibición — posible umbral hardcodeado"; FAIL=1; }
else
  echo "[PASS] ningún umbral hardcodeado en el skill"
fi

exit $FAIL
