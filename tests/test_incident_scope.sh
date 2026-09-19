#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: incident/scope-identification determina
# el mínimo conjunto de especialistas, nunca activa todos los dominios por defecto.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/incident/scope-identification/SKILL.md"

[ -f "$SKILL" ] || { echo "[FAIL] falta $SKILL"; FAIL=1; }

grep -qiE 'mínimo|minimo' "$SKILL" \
  && echo "[PASS] incident/scope-identification declara activación mínima" \
  || { echo "[FAIL] falta la declaración de activación mínima"; FAIL=1; }

grep -q 'incident.required_domains' "$ROOT/docs/TARGET_PROFILE.md" \
  && echo "[PASS] docs/TARGET_PROFILE.md declara incident.required_domains" \
  || { echo "[FAIL] falta incident.required_domains en docs/TARGET_PROFILE.md"; FAIL=1; }

grep -q 'nunca reduce el scope mínimo de seguridad' "$ROOT/docs/TARGET_PROFILE.md" \
  && echo "[PASS] incident.required_domains nunca reduce el scope mínimo de seguridad" \
  || { echo "[FAIL] falta la regla de no reducir el scope mínimo de seguridad"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] incident/scope-identification consistente con activación mínima"
exit $FAIL
