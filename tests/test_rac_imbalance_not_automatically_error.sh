#!/usr/bin/env bash
# Valida explícitamente el principio # 14: "Node 1 = 2x sessions NO significa automáticamente
# load balancing failure" — debe estar documentado textualmente, no sólo implícito.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/rac/session-distribution/SKILL.md"
A="$ROOT/agents/oracle-rac-analyst/AGENT.md"

grep -qi 'nunca concluir por sí solo' "$S" && echo "[PASS] session-distribution advierte explícitamente contra clasificar sin correlación" || { echo "[FAIL] falta la advertencia explícita"; FAIL=1; }
grep -qi 'Node 1 = 2x sessions' "$A" && echo "[PASS] AGENT.md cita el ejemplo canónico" || { echo "[FAIL] falta el ejemplo canónico en AGENT.md"; FAIL=1; }

exit $FAIL
