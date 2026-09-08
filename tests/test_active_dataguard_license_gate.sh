#!/usr/bin/env bash
# ACTIVE_DATA_GUARD_CHECK gate declarado explícitamente, nunca asumido licenciado (# 38).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
A="$ROOT/agents/oracle-dataguard-analyst/AGENT.md"
M="$ROOT/agents/oracle-dataguard-analyst/manifest.yaml"

grep -q 'ACTIVE_DATA_GUARD_CHECK' "$A" && echo "[PASS] AGENT.md declara ACTIVE_DATA_GUARD_CHECK" || { echo "[FAIL] falta el gate"; FAIL=1; }
grep -q 'active_data_guard_gate' "$M" && echo "[PASS] manifest.yaml declara active_data_guard_gate" || { echo "[FAIL] falta el gate en el manifest"; FAIL=1; }
grep -qi 'nunca se asume licenciado' "$M" && echo "[PASS] nunca asume licenciado por defecto" || { echo "[FAIL] falta la regla"; FAIL=1; }

exit $FAIL
