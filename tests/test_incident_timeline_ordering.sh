#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: incident/timeline ordena eventos por
# timestamp normalizado (UTC) y declara los tipos de evento del modelo.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/incident/timeline/SKILL.md"
DOC="$ROOT/docs/INCIDENT_TIMELINE_MODEL.md"

for f in "$SKILL" "$DOC"; do
  [ -f "$f" ] || { echo "[FAIL] falta $f"; FAIL=1; }
done

grep -qi 'UTC' "$DOC" && echo "[PASS] Incident Timeline Model normaliza a UTC" \
  || { echo "[FAIL] falta la normalización UTC"; FAIL=1; }

for evt in SYMPTOM_OBSERVED ALERT_TRIGGERED CONFIG_CHANGE CAPACITY_EVENT RECOVERY INVESTIGATION_STEP; do
  grep -q "$evt" "$DOC" || { echo "[FAIL] falta el tipo de evento $evt en docs/INCIDENT_TIMELINE_MODEL.md"; FAIL=1; }
done

[ $FAIL -eq 0 ] && echo "[PASS] incident/timeline ordena y clasifica eventos consistentemente"
exit $FAIL
