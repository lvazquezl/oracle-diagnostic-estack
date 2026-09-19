#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: playbook de OS memory pressure —
# referenciado en el Incident Playbook Model, respaldado por el fixture memory-pressure.txt.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
DOC="$ROOT/docs/INCIDENT_PLAYBOOK_MODEL.md"
FIXTURE="$ROOT/tests/fixtures/incident/os/memory-pressure.txt"

[ -f "$FIXTURE" ] || { echo "[FAIL] falta el fixture $FIXTURE"; FAIL=1; }

grep -qi 'OS memory pressure' "$DOC" \
  && echo "[PASS] docs/INCIDENT_PLAYBOOK_MODEL.md cubre OS memory pressure" \
  || { echo "[FAIL] falta la cobertura de OS memory pressure"; FAIL=1; }

grep -q 'incident/os-correlation' "$DOC" \
  && echo "[PASS] playbook referencia incident/os-correlation" \
  || { echo "[FAIL] falta la referencia a incident/os-correlation"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Playbook de OS memory pressure consistente"
exit $FAIL
