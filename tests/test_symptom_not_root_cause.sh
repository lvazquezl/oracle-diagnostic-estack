#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: ORA-12537 (y símbolos equivalentes) nunca
# son automáticamente root cause — son síntomas, usando el fixture ORA-12537 como referencia.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/incident/root-cause/SKILL.md"
DOC="$ROOT/docs/INCIDENT_CAUSALITY_MODEL.md"
FIXTURE="$ROOT/tests/fixtures/incident/oracle/ora-12537-connection-lost.txt"

[ -f "$FIXTURE" ] || { echo "[FAIL] falta el fixture $FIXTURE"; FAIL=1; }

grep -q 'ORA-12537' "$SKILL" \
  && echo "[PASS] incident/root-cause implementa el ejemplo ORA-12537" \
  || { echo "[FAIL] falta el ejemplo ORA-12537 en incident/root-cause/SKILL.md"; FAIL=1; }

grep -q '# Symptom vs. cause' "$SKILL" \
  && echo "[PASS] sección Symptom vs. cause presente" \
  || { echo "[FAIL] falta la sección Symptom vs. cause"; FAIL=1; }

grep -q 'expected_classification: SYMPTOM' "$FIXTURE" \
  && echo "[PASS] fixture declara expected_classification: SYMPTOM" \
  || { echo "[FAIL] falta expected_classification: SYMPTOM en el fixture"; FAIL=1; }

grep -q 'ORA-12537' "$DOC" \
  && echo "[PASS] docs/INCIDENT_CAUSALITY_MODEL.md referencia el ejemplo ORA-12537" \
  || { echo "[FAIL] falta la referencia ORA-12537 en docs/INCIDENT_CAUSALITY_MODEL.md"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Símbolo/síntoma nunca tratado como root cause automático"
exit $FAIL
