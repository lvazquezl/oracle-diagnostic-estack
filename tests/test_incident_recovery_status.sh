#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: incident/recovery-status declara el enum
# completo y el modelo mitigation/temporary_fix/permanent_fix/workaround.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/incident/recovery-status/SKILL.md"

for status in RECOVERED PARTIALLY_RECOVERED STABLE_WITH_RISK NOT_RECOVERED UNKNOWN; do
  grep -q "$status" "$SKILL" || { echo "[FAIL] falta el estado $status en incident/recovery-status/SKILL.md"; FAIL=1; }
done

for kind in MITIGATION TEMPORARY_FIX PERMANENT_FIX WORKAROUND; do
  grep -q "$kind" "$SKILL" || { echo "[FAIL] falta la categoría $kind en incident/recovery-status/SKILL.md"; FAIL=1; }
done

[ $FAIL -eq 0 ] && echo "[PASS] incident/recovery-status con enum y modelo de mitigation/fix completos"
exit $FAIL
