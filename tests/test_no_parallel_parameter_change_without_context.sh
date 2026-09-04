#!/usr/bin/env bash
# Valida que performance/parallelism nunca recomiende cambiar parallel_max_servers/DOP sin
# correlación CPU/I/O completa (# 31. PARALLELISM del prompt de Fase 3).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/performance/parallelism/SKILL.md"

grep -qi 'nunca recomendar\|nunca.*recomienda' "$S" && echo "[PASS] declara explícitamente que nunca recomienda sin contexto" || { echo "[FAIL] no declara la prohibición explícita"; FAIL=1; }
grep -q 'parallel_max_servers' "$S" && echo "[PASS] menciona parallel_max_servers explícitamente" || { echo "[FAIL] no menciona parallel_max_servers"; FAIL=1; }
grep -q 'siempre manual' "$S" && echo "[PASS] declara ejecución siempre manual" || { echo "[FAIL] no declara ejecución manual"; FAIL=1; }

exit $FAIL
