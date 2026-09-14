#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 72.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
MANIFEST="$ROOT/agents/oracle-security-analyst/manifest.yaml"

grep -qi "CREATE / ALTER / DROP USER" "$MANIFEST" && echo "[PASS] manifest prohíbe CREATE USER" || { echo "[FAIL] falta la prohibición"; FAIL=1; }

for f in $(find "$ROOT/agents/oracle-security-analyst" "$ROOT/skills/security" "$ROOT/queries/security" -type f 2>/dev/null); do
  while IFS=: read -r lineno _; do
    [ -z "$lineno" ] && continue
    window=$(sed -n "$((lineno>3?lineno-3:1)),${lineno}p" "$f")
    if ! echo "$window" | grep -qiE 'nunca|never|prohibid|forbidden'; then
      echo "[FAIL] $f:$lineno contiene CREATE USER ejecutable sin contexto de prohibición"
      FAIL=1
    fi
  done < <(grep -niE '^\s*CREATE\s+USER\s' "$f")
done
[ $FAIL -eq 0 ] && echo "[PASS] Ninguna capacidad real de ejecutar CREATE USER"

exit $FAIL
