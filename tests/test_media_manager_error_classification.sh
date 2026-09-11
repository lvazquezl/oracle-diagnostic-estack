#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 45/47.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/rman/sbt-media-manager/SKILL.md"

grep -q 'error_classification' "$S" && echo "[PASS] declara error_classification en el output schema" || { echo "[FAIL] falta error_classification"; FAIL=1; }
grep -qi 'ORA-19511' "$S" && echo "[PASS] reconoce ORA-19511 (error de media manager)" || { echo "[FAIL] falta ORA-19511"; FAIL=1; }
grep -qi 'sin asumir causa sin evidencia del lado vendor\|nunca asum' "$S" && echo "[PASS] documenta que nunca asume causa sin evidencia" || { echo "[FAIL] falta la prohibición de asumir sin evidencia"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Media manager error classification certificada"
exit $FAIL
