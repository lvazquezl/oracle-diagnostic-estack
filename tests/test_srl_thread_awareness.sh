#!/usr/bin/env bash
# dataguard/standby-redo-logs es thread-aware, compara online redo por thread.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/dataguard/standby-redo-logs/SKILL.md"

grep -qi 'por thread' "$S" && echo "[PASS] SRL es thread-aware" || { echo "[FAIL] falta awareness de thread"; FAIL=1; }
grep -qi 'threads RAC' "$S" && echo "[PASS] considera threads RAC" || { echo "[FAIL] falta consideración de RAC"; FAIL=1; }

exit $FAIL
