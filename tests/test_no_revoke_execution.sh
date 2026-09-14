#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 72.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in $(find "$ROOT/queries/security" -name 'Q-*.md' 2>/dev/null); do
  block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$f")
  if echo "$block" | grep -qiE '^\s*REVOKE\s'; then
    echo "[FAIL] $f (query certificada) contiene REVOKE ejecutable"
    FAIL=1
  fi
done
[ $FAIL -eq 0 ] && echo "[PASS] Ninguna query certificada de Security ejecuta REVOKE"

for f in $(find "$ROOT/skills/security" -type f 2>/dev/null); do
  while IFS=: read -r lineno _; do
    [ -z "$lineno" ] && continue
    window=$(sed -n "$((lineno>3?lineno-3:1)),${lineno}p" "$f")
    if ! echo "$window" | grep -qiE 'nunca|never|prohibid|forbidden|manual_action|MANUAL DBA ACTION|dependency analysis'; then
      echo "[FAIL] $f:$lineno contiene REVOKE ejecutable sin contexto de prohibición"
      FAIL=1
    fi
  done < <(grep -niE '^\s*REVOKE\s' "$f")
done
[ $FAIL -eq 0 ] && echo "[PASS] Ninguna capacidad real de ejecutar REVOKE"

exit $FAIL
