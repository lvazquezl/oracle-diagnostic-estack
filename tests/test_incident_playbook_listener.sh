#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: playbook de listener/TNS failure —
# referenciado en el Incident Playbook Model y respaldado por el fixture ORA-12537.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
DOC="$ROOT/docs/INCIDENT_PLAYBOOK_MODEL.md"
FIXTURE="$ROOT/tests/fixtures/incident/oracle/ora-12537-connection-lost.txt"

[ -f "$FIXTURE" ] || { echo "[FAIL] falta el fixture $FIXTURE"; FAIL=1; }

grep -qi 'Listener/TNS failure' "$DOC" \
  && echo "[PASS] docs/INCIDENT_PLAYBOOK_MODEL.md cubre Listener/TNS failure" \
  || { echo "[FAIL] falta la cobertura de Listener/TNS failure"; FAIL=1; }

grep -q 'incident/network-correlation' "$DOC" \
  && echo "[PASS] playbook referencia incident/network-correlation" \
  || { echo "[FAIL] falta la referencia a incident/network-correlation"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Playbook de listener/TNS consistente"
exit $FAIL
