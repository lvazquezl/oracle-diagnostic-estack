#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 44.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/rman/recovery-readiness/SKILL.md"
FX="$ROOT/tests/fixtures/19c-archivelog-backup-lag.yaml"

[ -f "$FX" ] || { echo "[FAIL] $FX no existe"; exit 1; }
grep -qi 'gap de archivelog' "$S" && echo "[PASS] rman/recovery-readiness reconoce gap de archivelog como bloqueador" || { echo "[FAIL] falta el reconocimiento del gap de archivelog"; FAIL=1; }
grep -qi 'backup_count: 0' "$FX" && echo "[PASS] fixture modela secuencias sin backup" || { echo "[FAIL] fixture no modela el gap"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] restore/recovery readiness missing archivelog certificado"
exit $FAIL
