#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 62.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
MANIFEST="$ROOT/agents/oracle-multitenant-analyst/manifest.yaml"

grep -qi "CREATE PLUGGABLE DATABASE" "$MANIFEST" && echo "[PASS] manifest prohíbe explícitamente CREATE PLUGGABLE DATABASE" || { echo "[FAIL] falta la prohibición de CREATE PLUGGABLE DATABASE"; FAIL=1; }

for f in $(find "$ROOT/queries/multitenant" "$ROOT/skills/multitenant" "$ROOT/agents/oracle-multitenant-analyst" -type f); do
  while IFS=: read -r lineno _; do
    [ -z "$lineno" ] && continue
    window=$(sed -n "$((lineno>15?lineno-15:1)),${lineno}p" "$f")
    if ! echo "$window" | grep -qiE 'nunca|never|prohibid|forbidden|no debe'; then
      echo "[FAIL] $f:$lineno menciona CREATE PLUGGABLE DATABASE sin contexto de prohibición"
      FAIL=1
    fi
  done < <(grep -niE 'CREATE PLUGGABLE DATABASE' "$f")
done

[ $FAIL -eq 0 ] && echo "[PASS] Ninguna capacidad real de CREATE PLUGGABLE DATABASE"

exit $FAIL
