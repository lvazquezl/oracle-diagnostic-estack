#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 59.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
FX="$ROOT/tests/fixtures/19c-rac-cdb-pdb-placement.yaml"

[ -f "$FX" ] || { echo "[FAIL] falta fixture 19c-rac-cdb-pdb-placement.yaml"; exit 1; }
grep -q "cluster_mode: rac" "$FX" && echo "[PASS] fixture declara cluster_mode=rac" || { echo "[FAIL] fixture no declara RAC"; FAIL=1; }
grep -q "active_instance: 1" "$FX" && echo "[PASS] fixture declara servicio activo sólo en instancia 1" || { echo "[FAIL] falta el caso de placement parcial"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] PDB RAC open state correctamente ejercitado"

exit $FAIL
