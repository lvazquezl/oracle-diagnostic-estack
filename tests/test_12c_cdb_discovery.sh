#!/usr/bin/env bash
# Valida el caso 12c CDB/PDB: fixture existe con PDBs listados, multitenant/container-state cubre el caso.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
FX="$ROOT/tests/fixtures/12c-cdb-pdb.yaml"

[ -f "$FX" ] || { echo "[FAIL] falta fixture 12c-cdb-pdb.yaml"; FAIL=1; }
grep -q 'major: 12' "$FX" 2>/dev/null && echo "[PASS] fixture declara oracle_version.major=12" || { echo "[FAIL] fixture no declara major=12"; FAIL=1; }
grep -q 'multitenant_mode: cdb' "$FX" 2>/dev/null && echo "[PASS] fixture declara multitenant_mode=cdb" || { echo "[FAIL] fixture no declara cdb"; FAIL=1; }
grep -q 'pdbs:' "$FX" 2>/dev/null && echo "[PASS] fixture lista PDBs" || { echo "[FAIL] fixture no lista PDBs"; FAIL=1; }

if grep -qi 'multitenant no existe antes de 12c' "$ROOT/docs/CAPABILITY_MATRIX.md" "$ROOT/config/capability-matrix.yaml" 2>/dev/null; then
  echo "[PASS] version-awareness documenta 12c como el punto de entrada de Multitenant"
else
  echo "[FAIL] version-awareness no documenta 12c como punto de entrada de Multitenant"
  FAIL=1
fi

exit $FAIL
