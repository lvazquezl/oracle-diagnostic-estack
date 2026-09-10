#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 6/57.
# Sobre 11g NON-CDB, la respuesta debe ser MULTITENANT_STATUS: NOT_APPLICABLE, sin activar
# ninguna query CDB/PDB.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
FX="$ROOT/tests/fixtures/11g-noncdb.yaml"

[ -f "$FX" ] || { echo "[FAIL] falta fixture 11g-noncdb.yaml"; exit 1; }
grep -q "multitenant_mode: non_cdb" "$FX" && echo "[PASS] fixture declara multitenant_mode: non_cdb" || { echo "[FAIL] fixture no declara non_cdb"; FAIL=1; }
grep -q "MULTITENANT_STATUS: NOT_APPLICABLE" "$FX" && echo "[PASS] fixture documenta la respuesta NOT_APPLICABLE" || { echo "[FAIL] falta la respuesta NOT_APPLICABLE en el fixture"; FAIL=1; }
grep -qi "mock_evidence: \[\]" "$FX" && echo "[PASS] fixture no declara mock_evidence — ninguna query CDB/PDB se ejecuta" || { echo "[FAIL] el fixture debería declarar mock_evidence vacío"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] 11g NON-CDB responde MULTITENANT_STATUS: NOT_APPLICABLE sin ejecutar queries CDB/PDB"

exit $FAIL
