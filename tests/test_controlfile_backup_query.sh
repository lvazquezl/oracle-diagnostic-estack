#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 42.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/rman/Q-RMAN-CONTROLFILE-BACKUP-001.md"

[ -f "$Q" ] || { echo "[FAIL] $Q no existe"; exit 1; }
grep -qi 'controlfile_included' "$Q" && echo "[PASS] filtra por CONTROLFILE_INCLUDED" || { echo "[FAIL] falta el filtro CONTROLFILE_INCLUDED"; FAIL=1; }
grep -qi 'nunca restaura\|nunca restaur' "$Q" && echo "[PASS] documenta que nunca restaura" || { echo "[FAIL] falta la prohibición de restore"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Q-RMAN-CONTROLFILE-BACKUP-001 certificada correctamente"
exit $FAIL
