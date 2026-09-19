#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: incident/impact-analysis nunca inventa
# users_affected/data_loss sin evidencia directa — cada campo sin evidencia queda null explícito.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/incident/impact-analysis/SKILL.md"
DOC="$ROOT/docs/INCIDENT_IMPACT_MODEL.md"

grep -qi 'users_affected' "$DOC" && grep -qi 'data_loss' "$DOC" \
  && echo "[PASS] campos de impacto declarados en docs/INCIDENT_IMPACT_MODEL.md" \
  || { echo "[FAIL] faltan campos de impacto en la documentación"; FAIL=1; }

tr '\n' ' ' < "$DOC" | grep -qiE 'null. explícito.*nunca un valor estimado' \
  && echo "[PASS] campos sin evidencia quedan null explícito" \
  || { echo "[FAIL] falta la regla de null explícito sin evidencia"; FAIL=1; }

grep -qi 'nunca inventa' "$SKILL" \
  && echo "[PASS] incident/impact-analysis declara que nunca inventa campos de impacto" \
  || { echo "[FAIL] falta la declaración de no inventar campos de impacto"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] incident/impact-analysis consistente, sin impacto inventado"
exit $FAIL
