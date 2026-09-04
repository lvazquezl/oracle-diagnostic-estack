#!/usr/bin/env bash
# Valida que performance/sql-cpu exista y reordene sobre la evidencia de performance/top-sql
# sin declarar una query propia adicional.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/performance/sql-cpu/SKILL.md"
M="$ROOT/skills/performance/sql-cpu/manifest.yaml"

[ -f "$S" ] && [ -f "$M" ] || { echo "[FAIL] falta performance/sql-cpu"; exit 1; }
grep -qi 'cpu_per_exec' "$S" && echo "[PASS] documenta cpu_per_exec" || { echo "[FAIL] no documenta cpu_per_exec"; FAIL=1; }
grep -q 'sin query propia' "$S" && echo "[PASS] declara explícitamente que reutiliza performance/top-sql sin query propia" || { echo "[FAIL] no declara la reutilización sin query propia"; FAIL=1; }

exit $FAIL
