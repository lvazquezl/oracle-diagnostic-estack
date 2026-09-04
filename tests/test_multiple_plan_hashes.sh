#!/usr/bin/env bash
# Valida que Q-PERF-PLAN-HIST-001 agrupe por plan_hash_value para detectar múltiples planes
# del mismo sql_id.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/performance/plans/Q-PERF-PLAN-HIST-001.md"

[ -f "$Q" ] || { echo "[FAIL] falta Q-PERF-PLAN-HIST-001.md"; exit 1; }
block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$Q")
echo "$block" | grep -qi 'GROUP.*BY.*plan_hash_value\|plan_hash_value' && echo "[PASS] agrupa por plan_hash_value" || { echo "[FAIL] no agrupa por plan_hash_value"; FAIL=1; }

exit $FAIL
