#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 9/57.
# Toda query Multitenant debe declarar container_scope dentro del enum:
# CDB_ROOT_ONLY|PDB_ONLY|ANY_CONTAINER|NON_CDB_ONLY|NOT_APPLICABLE
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
VALID='CDB_ROOT_ONLY|PDB_ONLY|ANY_CONTAINER|NON_CDB_ONLY|NOT_APPLICABLE'

for f in "$ROOT"/queries/multitenant/Q-*.md; do
  line=$(grep -m1 '^container_scope:' "$f" || true)
  if [ -z "$line" ]; then
    echo "[FAIL] $(basename "$f") no declara container_scope"
    FAIL=1
  elif ! echo "$line" | grep -Eq ": ($VALID)$"; then
    echo "[FAIL] $(basename "$f") declara container_scope fuera del enum: $line"
    FAIL=1
  else
    echo "[PASS] $(basename "$f") declara container_scope válido: $line"
  fi
done

[ $FAIL -eq 0 ] && echo "[PASS] Toda query Multitenant declara container_scope dentro del enum correcto"

exit $FAIL
