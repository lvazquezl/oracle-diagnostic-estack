#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 68.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/hugepages/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'suma' "$S" && echo "[PASS] declara suma de SGA de todas las instancias" || { echo "[FAIL] falta la regla de suma"; FAIL=1; }
grep -qi 'nunca calculado con una sola instancia si hay más' "$S" \
  && echo "[PASS] prohíbe calcular con una sola instancia cuando hay múltiples" || { echo "[FAIL] falta la prohibición"; FAIL=1; }
exit $FAIL
