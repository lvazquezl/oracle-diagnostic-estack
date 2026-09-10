#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 18/57.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/multitenant/Q-CDB-TEMP-001.md"
SKILL="$ROOT/skills/multitenant/pdb-temp/SKILL.md"

[ -f "$Q" ] || { echo "[FAIL] falta Q-CDB-TEMP-001.md"; exit 1; }
grep -qi "bytes_used" "$Q" && grep -qi "bytes_free" "$Q" && echo "[PASS] Q-CDB-TEMP-001 selecciona uso real de TEMP" || { echo "[FAIL] faltan columnas de uso"; FAIL=1; }
grep -qi "no resize" "$SKILL" && echo "[PASS] documenta que no resize/agrega tempfile automáticamente" || { echo "[FAIL] falta la prohibición de resize automático"; FAIL=1; }
grep -qi "oracle-performance-analyst" "$SKILL" && echo "[PASS] correlaciona con Performance para waits TEMP" || { echo "[FAIL] falta la correlación con Performance"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] PDB TEMP implementado correctamente"

exit $FAIL
