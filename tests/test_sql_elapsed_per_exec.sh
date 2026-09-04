#!/usr/bin/env bash
# Valida que performance/top-sql documente el cálculo de elapsed_per_exec con manejo seguro de
# división por cero (# 19. METRICS PER EXECUTION del prompt de Fase 3).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/performance/top-sql/SKILL.md"

grep -qi 'elapsed_per_exec' "$S" && echo "[PASS] documenta elapsed_per_exec" || { echo "[FAIL] no documenta elapsed_per_exec"; FAIL=1; }
grep -qi 'división por cero' "$S" && echo "[PASS] documenta manejo seguro de división por cero" || { echo "[FAIL] no documenta división por cero"; FAIL=1; }
grep -qi 'no asumir que un SQL con mucho elapsed' "$S" && echo "[PASS] declara la regla explícita de no juzgar por total" || { echo "[FAIL] falta la regla de no juzgar por total"; FAIL=1; }

exit $FAIL
