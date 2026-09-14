#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 72.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/oracle-processes/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -qi 'Nunca envía command-line arguments completos por defecto' "$S" \
  && echo "[PASS] prohíbe enviar command-line arguments completos por defecto" || { echo "[FAIL] falta la prohibición de argumentos"; FAIL=1; }
grep -q 'process_count_by_family' "$S" && echo "[PASS] declara process_count_by_family en el output" || { echo "[FAIL] falta process_count_by_family"; FAIL=1; }
exit $FAIL
