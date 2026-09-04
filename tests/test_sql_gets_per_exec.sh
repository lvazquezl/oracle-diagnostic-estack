#!/usr/bin/env bash
# Valida que performance/sql-io documente gets_per_exec.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/performance/sql-io/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta performance/sql-io/SKILL.md"; exit 1; }
grep -qi 'gets_per_exec' "$S" && echo "[PASS] documenta gets_per_exec" || { echo "[FAIL] no documenta gets_per_exec"; FAIL=1; }

exit $FAIL
