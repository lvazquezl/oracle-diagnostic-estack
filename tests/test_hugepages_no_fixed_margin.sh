#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 68.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/hugepages/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -qi 'ningún margen porcentual fijo' "$S" && echo "[PASS] prohíbe margen porcentual fijo" || { echo "[FAIL] falta la prohibición de margen fijo"; FAIL=1; }
grep -qi 'No inventar porcentaje fijo' "$S" && echo "[PASS] cita la regla fuente del prompt" || { echo "[FAIL] falta la cita de la regla fuente"; FAIL=1; }
exit $FAIL
