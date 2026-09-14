#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 72.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
MANIFEST="$ROOT/agents/oracle-security-analyst/manifest.yaml"

grep -qi "AUDIT / NOAUDIT" "$MANIFEST" && echo "[PASS] manifest prohíbe AUDIT/NOAUDIT" || { echo "[FAIL] falta la prohibición"; FAIL=1; }

for f in $(find "$ROOT/queries/security" -name 'Q-*.md' 2>/dev/null); do
  block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$f")
  if echo "$block" | grep -qiE '^\s*(AUDIT|NOAUDIT)\s'; then
    echo "[FAIL] $f (query certificada) contiene AUDIT/NOAUDIT ejecutable"
    FAIL=1
  fi
done
[ $FAIL -eq 0 ] && echo "[PASS] Ninguna query certificada de Security ejecuta AUDIT/NOAUDIT"

grep -qi "AUDIT POLICY" "$ROOT/skills/security/unified-auditing/SKILL.md" \
  && grep -qi "nunca habilita políticas" "$ROOT/skills/security/unified-auditing/SKILL.md" \
  && echo "[PASS] unified-auditing declara nunca habilitar políticas" \
  || { echo "[FAIL] falta la declaración en unified-auditing"; FAIL=1; }

exit $FAIL
