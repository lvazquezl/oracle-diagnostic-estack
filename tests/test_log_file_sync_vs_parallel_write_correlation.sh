#!/usr/bin/env bash
# Valida que performance/commit-redo distinga comportamiento de aplicación de latencia de
# storage de redo como hipótesis separadas, y que la fixture 19c-log-file-sync.yaml exista.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/performance/commit-redo/SKILL.md"

grep -qi 'application_commit_behavior\|comportamiento de commit de aplicación' "$S" && echo "[PASS] documenta hipótesis de comportamiento de aplicación" || { echo "[FAIL] no documenta comportamiento de aplicación"; FAIL=1; }
grep -qi 'redo_storage_latency\|latencia de storage de redo' "$S" && echo "[PASS] documenta hipótesis de latencia de storage" || { echo "[FAIL] no documenta latencia de storage"; FAIL=1; }
[ -f "$ROOT/tests/fixtures/19c-log-file-sync.yaml" ] && echo "[PASS] fixture 19c-log-file-sync.yaml existe" || { echo "[FAIL] falta fixture 19c-log-file-sync.yaml"; FAIL=1; }

exit $FAIL
