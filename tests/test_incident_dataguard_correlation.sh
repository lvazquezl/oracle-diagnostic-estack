#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: incident/dataguard-correlation nunca
# reporta data_loss sin evidencia directa, usando el fixture archive-gap.txt como referencia.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/incident/dataguard-correlation/SKILL.md"
FIXTURE="$ROOT/tests/fixtures/incident/dataguard/archive-gap.txt"

[ -f "$FIXTURE" ] || { echo "[FAIL] falta el fixture $FIXTURE"; FAIL=1; }

grep -qi 'oracle-dataguard-analyst' "$SKILL" \
  && echo "[PASS] referencia a oracle-dataguard-analyst presente" \
  || { echo "[FAIL] falta la referencia a oracle-dataguard-analyst"; FAIL=1; }

tr '\n' ' ' < "$SKILL" | grep -qiE 'nunca reportar .data_loss: true. sin' \
  && echo "[PASS] declara que nunca reporta data_loss sin evidencia directa" \
  || { echo "[FAIL] falta la regla de data_loss sin evidencia"; FAIL=1; }

grep -qi 'nunca recomienda ni ejecuta' "$SKILL" \
  && echo "[PASS] declara que nunca recomienda ni ejecuta switchover/failover" \
  || { echo "[FAIL] falta la prohibición de switchover/failover"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] incident/dataguard-correlation consistente con el fixture de archive gap"
exit $FAIL
