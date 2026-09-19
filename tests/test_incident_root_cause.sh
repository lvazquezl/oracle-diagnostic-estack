#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: incident/root-cause preserva el modelo
# FACT→OBSERVATION→HYPOTHESIS→PROBABLE_CAUSE→CONFIRMED_ROOT_CAUSE de docs/CONTRACTS.md#rca-model
# y exige causal_chain, nunca un salto directo alerta→causa.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/incident/root-cause/SKILL.md"
DOC="$ROOT/docs/INCIDENT_ROOT_CAUSE_MODEL.md"

grep -q 'FACT → OBSERVATION → HYPOTHESIS → PROBABLE_CAUSE → CONFIRMED_ROOT_CAUSE' "$DOC" \
  && echo "[PASS] docs/INCIDENT_ROOT_CAUSE_MODEL.md preserva la escala RCA de Foundation" \
  || { echo "[FAIL] falta la escala RCA completa"; FAIL=1; }

grep -qi 'causal_chain' "$SKILL" \
  && echo "[PASS] incident/root-cause exige causal_chain" \
  || { echo "[FAIL] falta la exigencia de causal_chain"; FAIL=1; }

grep -q 'docs/CONTRACTS.md#rca-model' "$DOC" \
  && echo "[PASS] docs/INCIDENT_ROOT_CAUSE_MODEL.md referencia docs/CONTRACTS.md#rca-model" \
  || { echo "[FAIL] falta la referencia a docs/CONTRACTS.md#rca-model"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] incident/root-cause consistente con el Root Cause Model"
exit $FAIL
