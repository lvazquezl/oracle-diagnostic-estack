#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: playbook de RAC node eviction — read-only,
# diagnose-and-recommend only, referenciado en el Incident Playbook Model y respaldado por fixture.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
DOC="$ROOT/docs/INCIDENT_PLAYBOOK_MODEL.md"
FIXTURE="$ROOT/tests/fixtures/incident/rac/node-eviction.txt"

[ -f "$FIXTURE" ] || { echo "[FAIL] falta el fixture $FIXTURE"; FAIL=1; }

grep -qi 'RAC node eviction' "$DOC" \
  && echo "[PASS] docs/INCIDENT_PLAYBOOK_MODEL.md cubre RAC node eviction" \
  || { echo "[FAIL] falta la cobertura de RAC node eviction"; FAIL=1; }

grep -qi 'read-only, diagnose-and-recommend only' "$DOC" \
  && echo "[PASS] principio read-only/diagnose-and-recommend declarado" \
  || { echo "[FAIL] falta el principio read-only/diagnose-and-recommend"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Playbook de RAC eviction consistente"
exit $FAIL
