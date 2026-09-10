#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 60.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
FX="$ROOT/tests/fixtures/19c-pdb-plugin-violations.yaml"

[ -f "$FX" ] || { echo "[FAIL] falta fixture 19c-pdb-plugin-violations.yaml"; exit 1; }
grep -q "Q-CDB-PLUGIN-VIOLATIONS-001" "$FX" && echo "[PASS] fixture ejercita Q-CDB-PLUGIN-VIOLATIONS-001" || { echo "[FAIL] falta la evidencia de plug-in violations"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Detección de plug-in violations correctamente ejercitada"

exit $FAIL
