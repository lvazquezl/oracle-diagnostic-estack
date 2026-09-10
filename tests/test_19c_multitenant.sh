#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 58.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
FX="$ROOT/tests/fixtures/19c-cdb-healthy.yaml"

[ -f "$FX" ] || { echo "[FAIL] falta fixture 19c-cdb-healthy.yaml"; exit 1; }
grep -q "major: 19" "$FX" && echo "[PASS] fixture declara oracle_version.major=19" || { echo "[FAIL] fixture no declara 19"; FAIL=1; }
grep -q "cdb: true" "$FX" && echo "[PASS] fixture declara multitenant.cdb=true" || { echo "[FAIL] fixture no declara cdb=true"; FAIL=1; }
grep -q "pdb_count: 3" "$FX" && echo "[PASS] fixture declara 3 PDBs" || { echo "[FAIL] fixture no declara pdb_count"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] 19c Multitenant correctamente soportado"

exit $FAIL
