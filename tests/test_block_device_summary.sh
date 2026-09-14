#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 71.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/block-devices/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -qi 'nunca reemplaza a' "$S" && grep -q 'oracle-asm-storage-analyst' "$S" \
  && echo "[PASS] declara que nunca reemplaza a oracle-asm-storage-analyst" || { echo "[FAIL] falta la regla de no-reemplazo de ASM"; FAIL=1; }
grep -q 'rotational' "$S" && echo "[PASS] declara awareness de rotational (SSD/HDD)" || { echo "[FAIL] falta rotational"; FAIL=1; }
exit $FAIL
