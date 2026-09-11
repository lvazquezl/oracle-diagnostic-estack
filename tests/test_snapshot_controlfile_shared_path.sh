#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 45/21.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/rman/snapshot-controlfile/SKILL.md"

grep -qi 'ASM.*compartido\|compartido por diseño' "$S" && echo "[PASS] reconoce ASM como path compartido de bajo riesgo" || { echo "[FAIL] falta el reconocimiento de ASM compartido"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] snapshot controlfile shared path certificado"
exit $FAIL
