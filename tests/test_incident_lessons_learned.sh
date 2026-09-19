#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: incident/lessons-learned nunca escribe
# automáticamente en knowledge/errors/ — toda promoción pasa por el flujo /change gobernado.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/incident/lessons-learned/SKILL.md"

grep -qi 'nunca escribe automáticamente en .knowledge/errors/' "$SKILL" \
  && echo "[PASS] incident/lessons-learned declara que nunca escribe automáticamente en knowledge/errors/" \
  || { echo "[FAIL] falta la prohibición de escritura automática en knowledge/errors/"; FAIL=1; }

grep -qi '/change.*gobernado\|EVOLUTION.md' "$SKILL" \
  && echo "[PASS] incident/lessons-learned referencia el flujo /change gobernado" \
  || { echo "[FAIL] falta la referencia al flujo /change gobernado"; FAIL=1; }

for category in KNOWLEDGE_GAP PLAYBOOK_GAP OBSERVABILITY_GAP PROCESS_GAP; do
  grep -q "$category" "$SKILL" || { echo "[FAIL] falta la categoría $category en incident/lessons-learned"; FAIL=1; }
done

[ $FAIL -eq 0 ] && echo "[PASS] incident/lessons-learned consistente"
exit $FAIL
