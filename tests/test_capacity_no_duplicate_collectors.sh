#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 82 (# 570 del prompt: "no duplicar
# collectors, consumir evidencia por referencia").
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
M="$ROOT/agents/capacity-analyst/manifest.yaml"
S="$ROOT/skills/capacity/os/SKILL.md"

[ -f "$M" ] || { echo "[FAIL] falta $M"; exit 1; }
[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'duplicar collectors ya certificados' "$M" && echo "[PASS] manifest.yaml prohíbe duplicar collectors certificados" || { echo "[FAIL] falta la prohibición de duplicar collectors"; FAIL=1; }
grep -q 'nunca duplica collectors' "$S" && echo "[PASS] capacity/os nunca duplica collectors de Fase 9" || { echo "[FAIL] falta la disciplina anti-duplicación en capacity/os"; FAIL=1; }
exit $FAIL
