#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 44.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/rman/recovery-readiness/SKILL.md"
SCHEMA="$ROOT/agents/oracle-backup-recovery-analyst/output-schema.yaml"

grep -q 'media_recovery_readiness: READY' "$SCHEMA" && echo "[PASS] output-schema declara media_recovery_readiness READY" || { echo "[FAIL] falta media_recovery_readiness en el schema"; FAIL=1; }
grep -qi 'sin gaps desde el backup base' "$S" && echo "[PASS] documenta el criterio de READY" || { echo "[FAIL] falta el criterio de READY"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] recovery readiness READY certificado"
exit $FAIL
