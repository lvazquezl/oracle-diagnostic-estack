#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 82/18 (# 539-554 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/oracle/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'rman/fra-pressure' "$S" && echo "[PASS] capacity/oracle referencia rman/fra-pressure (Fase 7) por evidence_refs" || { echo "[FAIL] falta la referencia a rman/fra-pressure"; FAIL=1; }
grep -qi 'nunca duplica la recolección' "$S" && echo "[PASS] capacity/oracle declara que nunca duplica la recolección de otros especialistas" || { echo "[FAIL] falta la disciplina anti-duplicación"; FAIL=1; }
exit $FAIL
