#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 62.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
MANIFEST="$ROOT/agents/oracle-multitenant-analyst/manifest.yaml"

grep -qiE "OPEN.{0,15}CLOSE|CLOSE.{0,15}OPEN|ALTER PLUGGABLE DATABASE.*(OPEN|CLOSE)" "$MANIFEST" \
  && echo "[PASS] manifest prohíbe OPEN/CLOSE PLUGGABLE DATABASE" \
  || { echo "[FAIL] falta la prohibición explícita de OPEN/CLOSE PLUGGABLE DATABASE"; FAIL=1; }

for f in $(find "$ROOT/queries/multitenant" "$ROOT/skills/multitenant" -type f -name "*.md"); do
  if grep -qiE "^\s*ALTER PLUGGABLE DATABASE.*(OPEN|CLOSE)" "$f"; then
    echo "[FAIL] $f contiene una sentencia ejecutable ALTER PLUGGABLE DATABASE OPEN/CLOSE"
    FAIL=1
  fi
done

[ $FAIL -eq 0 ] && echo "[PASS] Ninguna query/skill ejecuta OPEN/CLOSE de PDB — sólo visibilidad vía V\$PDBS.open_mode"

exit $FAIL
