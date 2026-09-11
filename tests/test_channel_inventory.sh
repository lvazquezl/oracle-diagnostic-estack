#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 44.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/rman/channels/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] $S no existe"; exit 1; }
grep -qi 'V\$BACKUP_DEVICE' "$S" && echo "[PASS] rman/channels lee V\$BACKUP_DEVICE" || { echo "[FAIL] falta V\$BACKUP_DEVICE"; FAIL=1; }
grep -qi 'V\$RMAN_CONFIGURATION' "$S" && echo "[PASS] rman/channels lee V\$RMAN_CONFIGURATION" || { echo "[FAIL] falta V\$RMAN_CONFIGURATION"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] rman/channels inventaría canales correctamente"
exit $FAIL
