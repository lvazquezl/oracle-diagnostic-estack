#!/usr/bin/env bash
# Valida que Q-PERF-WAIT-AWR-001 exista en su ubicación relocalizada y que performance/wait-events
# mantenga la regla de no usar Cluster como causa fuera de RAC.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

F="$ROOT/queries/performance/waits/Q-PERF-WAIT-AWR-001.md"
[ -f "$F" ] && echo "[PASS] Q-PERF-WAIT-AWR-001.md existe en queries/performance/waits/" || { echo "[FAIL] falta $F"; FAIL=1; }

S="$ROOT/skills/performance/wait-events/SKILL.md"
grep -qi 'nunca usarlo como causa si el target no es RAC\|nunca.*Cluster.*causa' "$S" && echo "[PASS] wait-events nunca usa Cluster como causa fuera de RAC" || { echo "[FAIL] falta la regla de Cluster/RAC"; FAIL=1; }

exit $FAIL
