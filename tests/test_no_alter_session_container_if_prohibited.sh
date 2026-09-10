#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 62.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
MANIFEST="$ROOT/agents/oracle-multitenant-analyst/manifest.yaml"

grep -qiE "ALTER SESSION SET CONTAINER" "$MANIFEST" \
  && echo "[PASS] manifest declara la condición de uso restringido de ALTER SESSION SET CONTAINER" \
  || { echo "[FAIL] falta la referencia a ALTER SESSION SET CONTAINER en forbidden_capabilities"; FAIL=1; }

for f in $(find "$ROOT/queries/multitenant" -type f -name "*.md"); do
  if grep -qiE "^\s*ALTER SESSION SET CONTAINER" "$f"; then
    echo "[FAIL] $f ejecuta ALTER SESSION SET CONTAINER — todas las queries multitenant deben ser CDB\$ROOT/CDB_* o CON_ID-filtradas, nunca cambiar de contenedor"
    FAIL=1
  fi
done

[ $FAIL -eq 0 ] && echo "[PASS] Ninguna query ejecuta ALTER SESSION SET CONTAINER de forma no controlada"

exit $FAIL
