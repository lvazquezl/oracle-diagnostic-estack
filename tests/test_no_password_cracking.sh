#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 67/72.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
MANIFEST="$ROOT/agents/oracle-security-analyst/manifest.yaml"

grep -qi "password cracking / guessing / brute-force" "$MANIFEST" \
  && echo "[PASS] manifest prohíbe explícitamente password cracking/guessing/brute-force" \
  || { echo "[FAIL] falta la prohibición explícita"; FAIL=1; }

PATTERN='crack_password\(|guess_password\(|brute_force\('
PROHIBITION_WORDS='nunca|never|prohibid|forbidden|no existe|not implement'
for f in $(find "$ROOT/agents/oracle-security-analyst" "$ROOT/skills/security" "$ROOT/queries/security" -type f 2>/dev/null); do
  while IFS=: read -r lineno _; do
    [ -z "$lineno" ] && continue
    window=$(sed -n "$((lineno>3?lineno-3:1)),${lineno}p" "$f")
    if ! echo "$window" | grep -qiE "$PROHIBITION_WORDS"; then
      echo "[FAIL] $f:$lineno contiene un patrón de password cracking sin contexto de prohibición"
      FAIL=1
    fi
  done < <(grep -niE "$PATTERN" "$f")
done
[ $FAIL -eq 0 ] && echo "[PASS] Ningún wrapper de password cracking en todo el dominio Security"

exit $FAIL
