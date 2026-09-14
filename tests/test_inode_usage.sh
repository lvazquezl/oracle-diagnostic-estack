#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 71.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/inodes/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -qi 'Detectar escenarios de muchos archivos pequeños' "$S" && echo "[PASS] cita la regla fuente de archivos pequeños" || { echo "[FAIL] falta la cita"; FAIL=1; }
grep -qi 'generan hallazgo.*NOT_APPLICABLE' "$S" && grep -qi 'falso .HEALTHY' "$S" \
  && echo "[PASS] declara NOT_APPLICABLE para filesystems sin modelo de inodes" || { echo "[FAIL] falta la regla NOT_APPLICABLE"; FAIL=1; }
exit $FAIL
