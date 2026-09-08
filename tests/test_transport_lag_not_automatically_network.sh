#!/usr/bin/env bash
# Regla explícita # 57: high transport lag does not prove a network problem.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/dataguard/lag/SKILL.md"
A="$ROOT/agents/oracle-dataguard-analyst/AGENT.md"

grep -qi 'NO prueba un problema de red' "$S" && echo "[PASS] lag declara explícitamente la regla # 57" || { echo "[FAIL] falta la regla # 57"; FAIL=1; }
grep -qi 'High transport lag does not prove a network problem\|does not prove' "$A" && echo "[PASS] AGENT.md cita la regla # 57" || { echo "[FAIL] falta cita en AGENT.md"; FAIL=1; }

exit $FAIL
