#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: clock skew se marca explícitamente vía
# TIMELINE_CONFIDENCE_DEGRADED, nunca "corregido" silenciosamente.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
DOC="$ROOT/docs/INCIDENT_TIMELINE_MODEL.md"
OS_SKILL="$ROOT/skills/incident/os-correlation/SKILL.md"
OS_FIXTURE="$ROOT/tests/fixtures/incident/os/time-sync-degradation.txt"

grep -qi 'TIMELINE_CONFIDENCE_DEGRADED' "$DOC" \
  && echo "[PASS] Incident Timeline Model declara TIMELINE_CONFIDENCE_DEGRADED" \
  || { echo "[FAIL] falta TIMELINE_CONFIDENCE_DEGRADED en docs/INCIDENT_TIMELINE_MODEL.md"; FAIL=1; }

tr '\n' ' ' < "$DOC" | grep -qi 'nunca[^.]*corregid' \
  && echo "[PASS] clock skew nunca se corrige silenciosamente" \
  || { echo "[FAIL] falta la declaración de no corregir silenciosamente el clock skew"; FAIL=1; }

[ -f "$OS_FIXTURE" ] || { echo "[FAIL] falta el fixture $OS_FIXTURE"; FAIL=1; }
grep -qi 'TIMELINE_CONFIDENCE_DEGRADED' "$OS_SKILL" \
  && echo "[PASS] incident/os-correlation referencia TIMELINE_CONFIDENCE_DEGRADED" \
  || { echo "[FAIL] falta la referencia en incident/os-correlation/SKILL.md"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Clock skew detectado y marcado, nunca corregido silenciosamente"
exit $FAIL
