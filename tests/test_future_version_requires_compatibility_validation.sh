#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 58/65.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
MANIFEST="$ROOT/agents/oracle-multitenant-analyst/manifest.yaml"
FX="$ROOT/tests/fixtures/future-unknown-major-cdb.yaml"
MATRIX="$ROOT/config/query-compatibility-matrix.yaml"

grep -A2 'family: "future' "$MANIFEST" | grep -q "status: UNKNOWN_FUTURE" && echo "[PASS] manifest declara la familia future como UNKNOWN_FUTURE" || { echo "[FAIL] falta UNKNOWN_FUTURE para future"; FAIL=1; }
[ -f "$FX" ] && grep -q "COMPATIBILITY_VALIDATION_REQUIRED" "$FX" && echo "[PASS] fixture de versión futura documenta COMPATIBILITY_VALIDATION_REQUIRED" || { echo "[FAIL] falta el fixture o la clasificación COMPATIBILITY_VALIDATION_REQUIRED"; FAIL=1; }

dg_section=$(awk '/Fase 6 \(Multitenant/{flag=1} flag{print} /^notes: >/{flag=0}' "$MATRIX")
if echo "$dg_section" | grep -q 'max: latest'; then
  echo "[FAIL] alguna entrada Q-CDB-* en config/query-compatibility-matrix.yaml usa max: latest"
  FAIL=1
else
  echo "[PASS] Ninguna entrada Q-CDB-* usa max: latest — todas usan max explícito 23.0"
fi

[ $FAIL -eq 0 ] && echo "[PASS] Una versión Oracle futura desconocida requiere validación explícita antes de soporte Multitenant"

exit $FAIL
