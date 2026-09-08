#!/usr/bin/env bash
# Toda query dataguard declara cost_class explícito; Q-DG-ARCHIVED-LOG-001 es MEDIUM (# 55).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in $(find "$ROOT/queries/dataguard" -name 'Q-*.md'); do
  grep -q '^cost_class:' "$f" && echo "[PASS] $(basename "$f") declara cost_class" || { echo "[FAIL] $(basename "$f") no declara cost_class"; FAIL=1; }
done

exit $FAIL
