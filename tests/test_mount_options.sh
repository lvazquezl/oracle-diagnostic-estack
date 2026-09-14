#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 71.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/mount-options/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -qi 'No declarar mala configuración sin contexto' "$S" && echo "[PASS] cita la regla fuente de no declarar sin contexto" || { echo "[FAIL] falta la cita"; FAIL=1; }
grep -qi 'CRITICAL.\{0,20\}sólo si el mount efectivamente aloja binarios' "$S" \
  && echo "[PASS] declara CRITICAL sólo cuando el mount aloja binarios Oracle" || { echo "[FAIL] falta la regla CRITICAL condicionada"; FAIL=1; }
exit $FAIL
