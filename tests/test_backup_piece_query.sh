#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 42.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/rman/Q-RMAN-BACKUP-PIECE-001.md"

[ -f "$Q" ] || { echo "[FAIL] $Q no existe"; exit 1; }
grep -qi 'v\$backup_piece' "$Q" && echo "[PASS] Q-RMAN-BACKUP-PIECE-001 lee V\$BACKUP_PIECE" || { echo "[FAIL] falta la fuente V\$BACKUP_PIECE"; FAIL=1; }
grep -q '^sensitivity: HIGH' "$Q" && echo "[PASS] sensitivity HIGH (HANDLE tokenizado)" || { echo "[FAIL] sensitivity no es HIGH"; FAIL=1; }
grep -qi 'TOKENIZE' "$Q" && echo "[PASS] documenta TOKENIZE de HANDLE" || { echo "[FAIL] falta la nota de sanitización de HANDLE"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Q-RMAN-BACKUP-PIECE-001 certificada correctamente"
exit $FAIL
