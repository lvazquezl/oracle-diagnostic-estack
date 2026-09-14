#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 67.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/platform-version/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -qi 'SUPPORTED|PARTIALLY_SUPPORTED|NOT_APPLICABLE|COMPATIBILITY_VALIDATION_REQUIRED' "$S" \
  && echo "[PASS] declara los 4 estados de soporte" || { echo "[FAIL] faltan los estados de soporte"; FAIL=1; }
grep -qi 'nunca asume equivalencia entre' "$S" && echo "[PASS] declara no asumir equivalencia entre distribuciones" || { echo "[FAIL] falta la regla de no-equivalencia"; FAIL=1; }
exit $FAIL
