#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: incident/severity-awareness nunca inventa
# impacto para justificar una severidad, y consulta el severity_model configurable del Target Profile.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/incident/severity-awareness/SKILL.md"

[ -f "$SKILL" ] || { echo "[FAIL] falta $SKILL"; FAIL=1; }

grep -qi 'nunca inventa impacto' "$SKILL" \
  && echo "[PASS] incident/severity-awareness declara que nunca inventa impacto" \
  || { echo "[FAIL] falta la declaración de no inventar impacto"; FAIL=1; }

grep -q 'incident.severity_model' "$SKILL" \
  && echo "[PASS] incident/severity-awareness referencia incident.severity_model del Target Profile" \
  || { echo "[FAIL] falta la referencia a incident.severity_model"; FAIL=1; }

grep -q 'incident:' "$ROOT/docs/TARGET_PROFILE.md" && grep -q 'severity_model' "$ROOT/docs/TARGET_PROFILE.md" \
  && echo "[PASS] docs/TARGET_PROFILE.md declara el bloque incident.severity_model" \
  || { echo "[FAIL] falta el bloque incident.severity_model en docs/TARGET_PROFILE.md"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] incident/severity-awareness consistente y sin severidad inventada"
exit $FAIL
