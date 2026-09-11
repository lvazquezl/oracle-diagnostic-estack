#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 44.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/rman/channels/SKILL.md"
FX="$ROOT/tests/fixtures/19c-rac-multiple-channels.yaml"

grep -qi 'parallelism' "$S" && echo "[PASS] rman/channels analiza parallelism" || { echo "[FAIL] falta análisis de parallelism"; FAIL=1; }
[ -f "$FX" ] && grep -qi 'DEVICE TYPE DISK PARALLELISM' "$FX" && echo "[PASS] fixture RAC declara parallelism configurado" || { echo "[FAIL] falta fixture de parallelism"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] parallelism de canales certificado"
exit $FAIL
