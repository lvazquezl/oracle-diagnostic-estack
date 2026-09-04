#!/usr/bin/env bash
# Valida que exista un workflow alternativo (performance-standard-path) que no dependa de
# AWR/ASH/ADDM/SQL Tuning Advisor — # 40 del prompt de Fase 3.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
A="$ROOT/agents/oracle-performance-analyst/AGENT.md"

grep -qi 'ruta estándar\|standard.*path\|performance-standard-path' "$A" && echo "[PASS] documenta la ruta estándar sin licencia" || { echo "[FAIL] no documenta la ruta estándar"; FAIL=1; }

for q in Q-PERF-DBTIME-CURRENT-001 Q-PERF-TOPSQL-CURRENT-001; do
  F=$(find "$ROOT/queries/performance" -name "$q.md")
  [ -n "$F" ] && grep -q 'license_requirements: none' "$F" && echo "[PASS] $q sin licencia (ruta estándar)" || { echo "[FAIL] $q no es una ruta sin licencia válida"; FAIL=1; }
done

exit $FAIL
