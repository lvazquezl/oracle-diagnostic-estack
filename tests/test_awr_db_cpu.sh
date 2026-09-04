#!/usr/bin/env bash
# Valida que performance/db-cpu nunca concluya "high DB CPU = CPU problem" sin correlación
# (# 15. DB CPU del prompt de Fase 3).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/performance/db-cpu/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta skills/performance/db-cpu/SKILL.md"; exit 1; }
grep -q 'top SQL' "$S" && echo "[PASS] performance/db-cpu correlaciona con top SQL" || { echo "[FAIL] performance/db-cpu no correlaciona con top SQL"; FAIL=1; }
grep -qi 'nunca.*concluir\|nunca concluye' "$S" && echo "[PASS] performance/db-cpu declara explícitamente que nunca concluye CPU-bound sin correlación" || { echo "[FAIL] falta la regla explícita de no concluir sin correlación"; FAIL=1; }

exit $FAIL
