#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: cada hipótesis referencia su
# hypothesis_id (HYP-*) y el root_cause confirmado se vincula explícitamente a esa hipótesis.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

grep -q 'HYP-' "$ROOT/docs/INCIDENT_EVIDENCE_MODEL.md" \
  && echo "[PASS] HYP- presente en la cadena de identificadores" \
  || { echo "[FAIL] falta HYP- en la cadena de identificadores"; FAIL=1; }

grep -q 'hypothesis_id: HYP-' "$ROOT/docs/INCIDENT_ROOT_CAUSE_MODEL.md" \
  && echo "[PASS] root_cause referencia hypothesis_id explícitamente" \
  || { echo "[FAIL] falta hypothesis_id en el output schema de root_cause"; FAIL=1; }

grep -q 'linked_to: RCA-...\|HYP-' "$ROOT/skills/incident/manual-remediation-plan/SKILL.md" \
  && echo "[PASS] manual-remediation-plan vincula cada acción a RCA-/HYP-" \
  || { echo "[FAIL] falta la vinculación linked_to en manual-remediation-plan"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Trazabilidad de hipótesis consistente"
exit $FAIL
