#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 42.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/rman/Q-RMAN-SPFILE-BACKUP-001.md"

[ -f "$Q" ] || { echo "[FAIL] $Q no existe"; exit 1; }
grep -qi 'v\$backup_spfile' "$Q" && echo "[PASS] Q-RMAN-SPFILE-BACKUP-001 lee V\$BACKUP_SPFILE" || { echo "[FAIL] falta la fuente V\$BACKUP_SPFILE"; FAIL=1; }
grep -qi 'nunca restaura\|nunca restaur' "$Q" && echo "[PASS] documenta que nunca restaura" || { echo "[FAIL] falta la prohibición de restore"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Q-RMAN-SPFILE-BACKUP-001 certificada correctamente"
exit $FAIL
