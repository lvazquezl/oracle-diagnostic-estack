#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 30/61.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/multitenant/Q-CDB-RESOURCE-USAGE-001.md"
FX="$ROOT/tests/fixtures/19c-pdb-resource-pressure.yaml"

[ -f "$Q" ] || { echo "[FAIL] falta Q-CDB-RESOURCE-USAGE-001.md"; exit 1; }
grep -qi "licensing-safe" "$Q" && echo "[PASS] documentada como licensing-safe" || { echo "[FAIL] falta la declaración licensing-safe"; FAIL=1; }
grep -qi "no requiere Diagnostics" "$Q" && echo "[PASS] no requiere Diagnostics/Tuning Pack" || { echo "[FAIL] falta la aclaración de licensing"; FAIL=1; }
[ -f "$FX" ] && echo "[PASS] fixture de presión de recursos existe" || { echo "[FAIL] falta el fixture"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] PDB resource usage implementado con fuentes licensing-safe"

exit $FAIL
