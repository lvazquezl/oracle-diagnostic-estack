#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 45/28.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/rman/dataguard-awareness/SKILL.md"
MANIFEST="$ROOT/agents/oracle-backup-recovery-analyst/manifest.yaml"

grep -q 'backup_offload_detected' "$S" && echo "[PASS] declara backup_offload_detected" || { echo "[FAIL] falta backup_offload_detected"; FAIL=1; }
grep -qi 'nunca ejecuta standby recovery' "$S" && echo "[PASS] documenta que nunca ejecuta standby recovery" || { echo "[FAIL] falta la prohibición de standby recovery"; FAIL=1; }
grep -qi 'nunca asume transportabilidad' "$S" && echo "[PASS] documenta que nunca asume transportabilidad de backup entre roles" || { echo "[FAIL] falta la prohibición de asumir transportabilidad"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Data Guard backup offload awareness certificado"
exit $FAIL
