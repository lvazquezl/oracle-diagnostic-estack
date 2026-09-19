#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: incident/intake declara los campos
# mínimos de intake y nunca inventa severidad sin declaración.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/incident/intake/SKILL.md"
MANIFEST="$ROOT/skills/incident/intake/manifest.yaml"
DOC="$ROOT/docs/INCIDENT_INTAKE_MODEL.md"

for f in "$SKILL" "$MANIFEST" "$DOC"; do
  [ -f "$f" ] || { echo "[FAIL] falta $f"; FAIL=1; }
done

grep -q 'id: incident/intake' "$MANIFEST" \
  && echo "[PASS] manifest.yaml declara id incident/intake" \
  || { echo "[FAIL] falta id incident/intake"; FAIL=1; }

grep -qi 'reported_by' "$DOC" && grep -qi 'symptom_description' "$DOC" \
  && echo "[PASS] Incident Intake Model declara los campos mínimos de intake" \
  || { echo "[FAIL] falta el esquema de campos mínimos en docs/INCIDENT_INTAKE_MODEL.md"; FAIL=1; }

grep -qi 'status: OPEN|INVESTIGATING|RESOLVED|CLOSED' "$DOC" \
  && echo "[PASS] Incident Intake Model declara el enum de status" \
  || { echo "[FAIL] falta el enum de status en docs/INCIDENT_INTAKE_MODEL.md"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] incident/intake completo y consistente"
exit $FAIL
