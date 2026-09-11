#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 42.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/rman/Q-RMAN-FRA-USAGE-001.md"

[ -f "$Q" ] || { echo "[FAIL] $Q no existe"; exit 1; }
grep -qi 'v\$flash_recovery_area_usage' "$Q" && echo "[PASS] lee V\$FLASH_RECOVERY_AREA_USAGE" || { echo "[FAIL] falta V\$FLASH_RECOVERY_AREA_USAGE"; FAIL=1; }
grep -qi 'v\$recovery_file_dest' "$Q" && echo "[PASS] lee V\$RECOVERY_FILE_DEST" || { echo "[FAIL] falta V\$RECOVERY_FILE_DEST"; FAIL=1; }
grep -qi 'nunca ejecuta ninguna operación de limpieza\|nunca borra archivos' "$Q" && echo "[PASS] documenta que nunca borra archivos" || { echo "[FAIL] falta la prohibición de borrado"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Q-RMAN-FRA-USAGE-001 certificada correctamente"
exit $FAIL
