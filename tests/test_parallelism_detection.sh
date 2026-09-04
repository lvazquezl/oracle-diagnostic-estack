#!/usr/bin/env bash
# Valida que Q-PERF-PARALLEL-001 use V$PX_SESSION y detecte degradación degree < req_degree.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
F="$ROOT/queries/performance/parallel/Q-PERF-PARALLEL-001.md"
S="$ROOT/skills/performance/parallelism/SKILL.md"

[ -f "$F" ] || { echo "[FAIL] falta Q-PERF-PARALLEL-001.md"; exit 1; }
grep -qi 'v\$px_session' "$F" && echo "[PASS] usa V\$PX_SESSION" || { echo "[FAIL] no usa V\$PX_SESSION"; FAIL=1; }
grep -q 'degree.*req_degree\|req_degree.*degree' "$S" && echo "[PASS] performance/parallelism compara degree vs req_degree" || { echo "[FAIL] no compara degree vs req_degree"; FAIL=1; }

exit $FAIL
