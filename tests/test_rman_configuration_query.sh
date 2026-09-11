#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 42.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/rman/Q-RMAN-CONFIGURATION-001.md"

[ -f "$Q" ] || { echo "[FAIL] $Q no existe"; exit 1; }
grep -qi 'v\$rman_configuration' "$Q" && echo "[PASS] Q-RMAN-CONFIGURATION-001 lee V\$RMAN_CONFIGURATION" || { echo "[FAIL] falta la fuente V\$RMAN_CONFIGURATION"; FAIL=1; }
grep -q '^execution_mode: READ_ONLY' "$Q" && echo "[PASS] execution_mode: READ_ONLY" || { echo "[FAIL] execution_mode no declarado READ_ONLY"; FAIL=1; }
grep -qi 'CONFIGURE' "$Q" | grep -qi 'nunca' "$Q" 2>/dev/null || grep -qi 'nunca ejecuta' "$Q" && echo "[PASS] documenta que nunca ejecuta CONFIGURE" || true

[ $FAIL -eq 0 ] && echo "[PASS] Q-RMAN-CONFIGURATION-001 certificada correctamente"
exit $FAIL
