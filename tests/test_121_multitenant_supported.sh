#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 58.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
MANIFEST="$ROOT/agents/oracle-multitenant-analyst/manifest.yaml"
FX="$ROOT/tests/fixtures/121-cdb-2pdbs.yaml"

grep -A2 'family: "12.1"' "$MANIFEST" | grep -q "status: KNOWN_SUPPORTED" && echo "[PASS] manifest declara 12.1 como KNOWN_SUPPORTED" || { echo "[FAIL] falta KNOWN_SUPPORTED para 12.1"; FAIL=1; }
grep -A2 'family: "12.1"' "$MANIFEST" | grep -qi "Local Undo NO existe" && echo "[PASS] manifest aclara que Local Undo no existe en 12.1" || { echo "[FAIL] falta la aclaración de Local Undo en 12.1"; FAIL=1; }
[ -f "$FX" ] && echo "[PASS] fixture 121-cdb-2pdbs.yaml existe" || { echo "[FAIL] falta el fixture 12.1"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] 12.1 correctamente soportado como legacy, sin Local Undo"

exit $FAIL
