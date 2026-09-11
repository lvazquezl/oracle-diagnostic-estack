#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 44.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/rman/restore-readiness/SKILL.md"

grep -qi 'dependencia de media manager' "$S" && echo "[PASS] rman/restore-readiness reconoce dependencia de media manager" || { echo "[FAIL] falta el reconocimiento de dependencia SBT"; FAIL=1; }
grep -qi 'READY_WITH_WARNINGS' "$S" && echo "[PASS] declara READY_WITH_WARNINGS para dependencias no confirmadas" || { echo "[FAIL] falta READY_WITH_WARNINGS"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] restore readiness SBT dependency certificado"
exit $FAIL
