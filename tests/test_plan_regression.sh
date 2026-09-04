#!/usr/bin/env bash
# Valida que performance/plan-regression exista, requiera Diagnostics Pack (Q-PERF-PLAN-HIST-001),
# y nunca recomiende SPM automáticamente.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/performance/plan-regression/SKILL.md"
Q="$ROOT/queries/performance/plans/Q-PERF-PLAN-HIST-001.md"

[ -f "$S" ] && [ -f "$Q" ] || { echo "[FAIL] falta performance/plan-regression o Q-PERF-PLAN-HIST-001"; exit 1; }
grep -q 'license_requirements: \[Diagnostics Pack\]' "$Q" && echo "[PASS] Q-PERF-PLAN-HIST-001 requiere Diagnostics Pack" || { echo "[FAIL] no requiere Diagnostics Pack"; FAIL=1; }
grep -qi 'nunca recomendar SPM\|nunca.*SPM.*automátic' "$S" && echo "[PASS] nunca recomienda SPM automáticamente" || { echo "[FAIL] no declara la prohibición de SPM automático"; FAIL=1; }

exit $FAIL
