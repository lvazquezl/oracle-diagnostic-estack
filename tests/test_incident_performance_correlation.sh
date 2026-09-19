#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: incident/performance-correlation reutiliza
# evidencia de oracle-performance-analyst por referencia, nunca vuelve a consultar AWR/ASH.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/incident/performance-correlation/SKILL.md"

[ -f "$SKILL" ] || { echo "[FAIL] falta $SKILL"; FAIL=1; }

grep -qi 'oracle-performance-analyst' "$SKILL" \
  && echo "[PASS] referencia a oracle-performance-analyst presente" \
  || { echo "[FAIL] falta la referencia a oracle-performance-analyst"; FAIL=1; }

grep -qi 'nunca vuelve a consultar AWR/ASH' "$SKILL" \
  && echo "[PASS] declara que nunca duplica collectors AWR/ASH" \
  || { echo "[FAIL] falta la declaración de no duplicar collectors"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] incident/performance-correlation consistente"
exit $FAIL
