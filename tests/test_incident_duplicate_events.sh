#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: incident/timeline deduplica eventos
# idénticos reportados por múltiples fuentes sin perder la referencia a cada fuente original.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/incident/timeline/SKILL.md"

grep -qi 'dedup' "$SKILL" \
  && echo "[PASS] incident/timeline declara deduplicación de eventos" \
  || { echo "[FAIL] falta la declaración de deduplicación"; FAIL=1; }

grep -qi 'dedup' "$ROOT/docs/INCIDENT_TIMELINE_MODEL.md" \
  && echo "[PASS] docs/INCIDENT_TIMELINE_MODEL.md declara deduplicación" \
  || { echo "[FAIL] falta la deduplicación en docs/INCIDENT_TIMELINE_MODEL.md"; FAIL=1; }

tr '\n' ' ' < "$ROOT/docs/INCIDENT_TIMELINE_MODEL.md" | grep -qi 'sin perder la referencia a cada[[:space:]]*fuente' \
  && echo "[PASS] deduplicación preserva referencia a cada fuente original" \
  || { echo "[FAIL] falta la preservación de referencias de fuente en dedup"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Deduplicación de eventos consistente"
exit $FAIL
