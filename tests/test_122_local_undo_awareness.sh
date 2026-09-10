#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 58.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
MANIFEST="$ROOT/agents/oracle-multitenant-analyst/manifest.yaml"
FX="$ROOT/tests/fixtures/122-cdb-local-undo.yaml"

grep -A2 'family: "12.2"' "$MANIFEST" | grep -q "status: KNOWN_SUPPORTED" && echo "[PASS] manifest declara 12.2 como KNOWN_SUPPORTED" || { echo "[FAIL] falta KNOWN_SUPPORTED para 12.2"; FAIL=1; }
grep -A2 'family: "12.2"' "$MANIFEST" | grep -qi "Local Undo disponible" && echo "[PASS] manifest declara Local Undo disponible desde 12.2" || { echo "[FAIL] falta la aclaración de Local Undo en 12.2"; FAIL=1; }
[ -f "$FX" ] && grep -q "local_undo_enabled: true" "$FX" && echo "[PASS] fixture 122-cdb-local-undo.yaml declara local_undo_enabled: true" || { echo "[FAIL] falta el fixture 12.2 con local_undo_enabled"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Local Undo correctamente soportado desde 12.2"

exit $FAIL
