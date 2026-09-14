#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 72.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/oracle-groups/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -qi 'Nunca crea/modifica/elimina un grupo' "$S" && echo "[PASS] prohíbe crear/modificar/eliminar grupos" || { echo "[FAIL] falta la prohibición de grupos"; FAIL=1; }
grep -qi 'nunca cambia membresía' "$S" && echo "[PASS] prohíbe cambiar membresía" || { echo "[FAIL] falta la prohibición de membresía"; FAIL=1; }
exit $FAIL
