#!/usr/bin/env bash
# Valida que toda query bajo queries/oracle/ declare execution_mode: READ_ONLY.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in $(find "$ROOT/queries/oracle" -name 'Q-*.md'); do
  if grep -q '^execution_mode: READ_ONLY$' "$f"; then
    echo "[PASS] $f declara execution_mode: READ_ONLY"
  else
    echo "[FAIL] $f no declara execution_mode: READ_ONLY"
    FAIL=1
  fi
done

exit $FAIL
