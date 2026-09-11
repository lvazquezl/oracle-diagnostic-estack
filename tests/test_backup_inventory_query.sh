#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 42.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/rman/Q-RMAN-BACKUP-SET-001.md"

[ -f "$Q" ] || { echo "[FAIL] $Q no existe"; exit 1; }
grep -qi 'v\$backup_set' "$Q" && echo "[PASS] Q-RMAN-BACKUP-SET-001 lee V\$BACKUP_SET" || { echo "[FAIL] falta la fuente V\$BACKUP_SET"; FAIL=1; }
grep -q 'variant_id: Q-RMAN-BACKUP-SET-001-V1' "$Q" && grep -q 'variant_id: Q-RMAN-BACKUP-SET-001-V2' "$Q" \
  && echo "[PASS] declara variantes legacy (10g-11g) y multitenant_aware (12.1+)" \
  || { echo "[FAIL] faltan las 2 variantes esperadas"; FAIL=1; }
grep -q 'container_scope: NOT_APPLICABLE' "$Q" && echo "[PASS] V1 container_scope NOT_APPLICABLE" || { echo "[FAIL] V1 no declara container_scope NOT_APPLICABLE"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Q-RMAN-BACKUP-SET-001 certificada correctamente"
exit $FAIL
