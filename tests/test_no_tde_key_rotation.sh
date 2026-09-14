#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 72.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/security/tde-awareness/SKILL.md"

grep -qi "ROTATE KEY" "$S" && grep -A3 "^# Forbidden operations" "$S" | grep -qi "ADMINISTER KEY MANAGEMENT" \
  && echo "[PASS] tde-awareness prohíbe rotación de claves" \
  || { echo "[FAIL] falta la prohibición de rotación de claves"; FAIL=1; }

for f in $(find "$ROOT/queries/security" -name 'Q-*.md' 2>/dev/null); do
  block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$f")
  if echo "$block" | grep -qiE 'SET\s+KEY|ROTATE\s+KEY'; then
    echo "[FAIL] $f (query certificada) contiene rotación de clave ejecutable"
    FAIL=1
  fi
done
[ $FAIL -eq 0 ] && echo "[PASS] Ninguna query certificada de Security rota claves"

exit $FAIL
