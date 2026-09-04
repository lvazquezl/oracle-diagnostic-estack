#!/usr/bin/env bash
# Valida que performance/sga nunca recomiende memoria basándose en un ratio aislado
# (# 22. SGA del prompt de Fase 3: prohíbe "buffer cache hit ratio < X = increase cache").
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/performance/sga/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta performance/sga/SKILL.md"; exit 1; }
grep -qi 'NO aplicar la regla' "$S" && echo "[PASS] prohíbe explícitamente la regla de ratio aislado" || { echo "[FAIL] no prohíbe la regla de ratio aislado"; FAIL=1; }
grep -qi 'hit ratio' "$S" && echo "[PASS] menciona hit ratio explícitamente en el contexto de la prohibición" || { echo "[FAIL] no menciona hit ratio"; FAIL=1; }

exit $FAIL
