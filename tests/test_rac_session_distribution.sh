#!/usr/bin/env bash
# rac/session-distribution: modelo instance/service/sessions/active/inactive/percentage/imbalance_ratio (# 14).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/rac/session-distribution/SKILL.md"

for field in active_sessions inactive_sessions pct_of_total imbalance_ratio; do
  grep -q "$field" "$S" && echo "[PASS] session-distribution declara $field" || { echo "[FAIL] falta $field"; FAIL=1; }
done
grep -q 'CONFIGURATION|CLIENT_BEHAVIOR|POOLING|SERVICE_AFFINITY|WORKLOAD|FAILOVER_HISTORY|INSUFFICIENT_EVIDENCE' "$S" \
  && echo "[PASS] clasificación de causa completa presente" || { echo "[FAIL] falta la clasificación de causa"; FAIL=1; }

exit $FAIL
