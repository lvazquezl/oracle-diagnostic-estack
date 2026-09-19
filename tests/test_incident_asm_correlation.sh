#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: incident/asm-storage-correlation nunca
# recomienda ni ejecuta resize/rebalance — sólo diagnostica.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/incident/asm-storage-correlation/SKILL.md"

[ -f "$SKILL" ] || { echo "[FAIL] falta $SKILL"; FAIL=1; }

grep -qi 'oracle-asm-storage-analyst' "$SKILL" \
  && echo "[PASS] referencia a oracle-asm-storage-analyst presente" \
  || { echo "[FAIL] falta la referencia a oracle-asm-storage-analyst"; FAIL=1; }

grep -qi 'nunca recomienda ni ejecuta resize/rebalance' "$SKILL" \
  && echo "[PASS] declara que nunca ejecuta/recomienda resize/rebalance" \
  || { echo "[FAIL] falta la prohibición de resize/rebalance"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] incident/asm-storage-correlation consistente"
exit $FAIL
