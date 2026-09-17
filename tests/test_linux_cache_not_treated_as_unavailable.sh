#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 12 (# 442 del prompt):
# no tratar Linux page cache como consumo irreclamable.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/memory/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'page cache de Linux nunca se trata como memoria consumida' "$S" && echo "[PASS] declara que el page cache nunca se trata como consumo irreclamable" || { echo "[FAIL] falta la disciplina anti-page-cache"; FAIL=1; }
grep -q 'falso positivo que este skill evita' "$S" && echo "[PASS] declara el falso positivo evitado explícitamente" || { echo "[FAIL] falta la sección False positives"; FAIL=1; }
exit $FAIL
