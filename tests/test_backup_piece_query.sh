#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 42.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/rman/Q-RMAN-BACKUP-PIECE-001.md"

[ -f "$Q" ] || { echo "[FAIL] $Q no existe"; exit 1; }
grep -qi 'v\$backup_piece' "$Q" && echo "[PASS] Q-RMAN-BACKUP-PIECE-001 lee V\$BACKUP_PIECE" || { echo "[FAIL] falta la fuente V\$BACKUP_PIECE"; FAIL=1; }
# CHG-ESTACK-B8-OPS-COVERAGE-001: HANDLE y TAG ya no se tokenizan: nunca se seleccionan (agregado por dispositivo y estado).
sql=$(awk '/```sql/{f=1;next} /```/{f=0} f' "$Q")
grep -qiwE 'handle|tag' <<<"$sql" && { echo "[FAIL] el SQL selecciona HANDLE o TAG"; FAIL=1; } || echo "[PASS] el SQL no selecciona HANDLE ni TAG"
grep -qi 'HANDLE.*nunca se seleccionan\|HANDLE.*no salen de la base' "$Q" && echo "[PASS] documenta que HANDLE no sale de la base" || { echo "[FAIL] falta la nota de sanitización de HANDLE"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Q-RMAN-BACKUP-PIECE-001 certificada correctamente"
exit $FAIL
