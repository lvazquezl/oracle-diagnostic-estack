#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 82/19 (# 557-573 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/os/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'nunca duplica collectors' "$S" && echo "[PASS] capacity/os declara que nunca duplica collectors de Fase 9" || { echo "[FAIL] falta la disciplina anti-duplicación"; FAIL=1; }
grep -q 'os/cpu-topology' "$S" && echo "[PASS] capacity/os referencia os/cpu-topology (Fase 9) por evidence_refs" || { echo "[FAIL] falta la referencia a os/cpu-topology"; FAIL=1; }
exit $FAIL
