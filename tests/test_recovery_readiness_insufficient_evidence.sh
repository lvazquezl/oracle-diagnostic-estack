#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 44.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/rman/recovery-readiness/SKILL.md"

grep -qi 'INSUFFICIENT_EVIDENCE' "$S" && echo "[PASS] rman/recovery-readiness declara INSUFFICIENT_EVIDENCE" || { echo "[FAIL] falta INSUFFICIENT_EVIDENCE"; FAIL=1; }
grep -qi 'nunca se asume.*READY\|nunca.*NOT_READY sin evidencia\|prerequisito' "$S" && echo "[PASS] documenta que nunca se asume el mejor/peor caso" || { echo "[FAIL] falta la prohibición de asumir sin evidencia"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] recovery readiness INSUFFICIENT_EVIDENCE certificado"
exit $FAIL
