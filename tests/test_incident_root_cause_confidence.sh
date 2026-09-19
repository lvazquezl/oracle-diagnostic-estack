#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: confidence HIGH|MEDIUM|LOW|INSUFFICIENT
# con score opcional 0.0-1.0 siempre acompañado de explicación, nunca un número sin justificación.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
DOC="$ROOT/docs/INCIDENT_ROOT_CAUSE_MODEL.md"

grep -q 'confidence: HIGH|MEDIUM|LOW|INSUFFICIENT' "$DOC" \
  && echo "[PASS] escala de confidence declarada" \
  || { echo "[FAIL] falta la escala de confidence"; FAIL=1; }

grep -qi 'confidence_score' "$DOC" && grep -qi 'confidence_explanation' "$DOC" \
  && echo "[PASS] confidence_score siempre acompañado de confidence_explanation" \
  || { echo "[FAIL] falta confidence_score/confidence_explanation"; FAIL=1; }

tr '\n' ' ' < "$DOC" | grep -qi 'nunca un número sin justificación\|siempre acompañado de explanation' \
  && echo "[PASS] regla de nunca-score-sin-explicación presente" \
  || { echo "[FAIL] falta la regla de no dar score sin explicación"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Modelo de confidence de root cause completo"
exit $FAIL
