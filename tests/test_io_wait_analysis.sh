#!/usr/bin/env bash
# Valida que Q-PERF-IO-001/Q-PERF-IO-FILESTAT-001 existan y que performance/io correlacione
# log file sync con log file parallel write.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for q in Q-PERF-IO-001 Q-PERF-IO-FILESTAT-001; do
  F=$(find "$ROOT/queries/performance/io" -name "$q.md")
  [ -n "$F" ] && echo "[PASS] $q.md existe" || { echo "[FAIL] falta $q.md"; FAIL=1; }
done

S="$ROOT/skills/performance/io/SKILL.md"
grep -qi 'log file sync' "$S" && grep -qi 'log file parallel write' "$S" && echo "[PASS] correlaciona log file sync con log file parallel write" || { echo "[FAIL] no correlaciona ambos eventos"; FAIL=1; }

exit $FAIL
