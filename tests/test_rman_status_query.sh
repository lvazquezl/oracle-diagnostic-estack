#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 42.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/rman/Q-RMAN-STATUS-001.md"

[ -f "$Q" ] || { echo "[FAIL] $Q no existe"; exit 1; }
grep -qi 'v\$rman_status' "$Q" && echo "[PASS] lee V\$RMAN_STATUS" || { echo "[FAIL] falta V\$RMAN_STATUS"; FAIL=1; }
grep -qi 'COMPLETED WITH WARNINGS' "$Q" && echo "[PASS] normaliza COMPLETED WITH WARNINGS real" || { echo "[FAIL] falta la normalización de estados reales"; FAIL=1; }
grep -qi 'nunca se inventa\|nunca inventa\|no se inventa' "$Q" && echo "[PASS] documenta que nunca inventa un mapping" || { echo "[FAIL] falta la prohibición de inventar mapping"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Q-RMAN-STATUS-001 certificada correctamente"
exit $FAIL
