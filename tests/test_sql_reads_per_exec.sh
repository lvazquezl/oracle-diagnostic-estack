#!/usr/bin/env bash
# Valida que performance/sql-io documente reads_per_exec y correlacione con performance/io.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/performance/sql-io/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta performance/sql-io/SKILL.md"; exit 1; }
grep -qi 'reads_per_exec' "$S" && echo "[PASS] documenta reads_per_exec" || { echo "[FAIL] no documenta reads_per_exec"; FAIL=1; }
grep -q 'performance/io' "$S" && echo "[PASS] correlaciona con performance/io" || { echo "[FAIL] no correlaciona con performance/io"; FAIL=1; }

exit $FAIL
