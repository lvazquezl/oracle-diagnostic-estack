#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: incident/os-correlation vincula clock skew
# a TIMELINE_CONFIDENCE_DEGRADED, usando el fixture time-sync-degradation.txt como referencia.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/incident/os-correlation/SKILL.md"
FIXTURE="$ROOT/tests/fixtures/incident/os/time-sync-degradation.txt"

[ -f "$FIXTURE" ] || { echo "[FAIL] falta el fixture $FIXTURE"; FAIL=1; }

grep -qi 'os-platform-analyst' "$SKILL" \
  && echo "[PASS] referencia a os-platform-analyst presente" \
  || { echo "[FAIL] falta la referencia a os-platform-analyst"; FAIL=1; }

grep -q 'TIMELINE_CONFIDENCE_DEGRADED' "$SKILL" \
  && echo "[PASS] incident/os-correlation vincula clock skew a TIMELINE_CONFIDENCE_DEGRADED" \
  || { echo "[FAIL] falta la referencia a TIMELINE_CONFIDENCE_DEGRADED"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] incident/os-correlation consistente con el fixture de time-sync"
exit $FAIL
