#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: incident/contradiction-analysis implementa
# el ejemplo de contradicción de latencia de storage del propio prompt, y una hipótesis con
# contradicción no resuelta nunca alcanza CONFIRMED.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/incident/contradiction-analysis/SKILL.md"

[ -f "$SKILL" ] || { echo "[FAIL] falta $SKILL"; FAIL=1; }

grep -qi 'storage latency' "$SKILL" \
  && echo "[PASS] incident/contradiction-analysis implementa el ejemplo de contradicción de storage" \
  || { echo "[FAIL] falta el ejemplo de contradicción de storage"; FAIL=1; }

tr '\n' ' ' < "$ROOT/docs/INCIDENT_HYPOTHESIS_MODEL.md" | grep -qi 'nunca[^.]*alcanza[^.]*CONFIRMED' \
  && echo "[PASS] una hipótesis con contradicción no resuelta nunca alcanza CONFIRMED" \
  || { echo "[FAIL] falta la regla de contradicción no resuelta bloqueando CONFIRMED"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] incident/contradiction-analysis completo"
exit $FAIL
