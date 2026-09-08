#!/usr/bin/env bash
# Toda query dataguard declara database_role_scope explícito.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in $(find "$ROOT/queries/dataguard" -name 'Q-*.md'); do
  grep -q '^database_role_scope:' "$f" && echo "[PASS] $(basename "$f") declara database_role_scope" || { echo "[FAIL] $(basename "$f") no declara database_role_scope"; FAIL=1; }
done

exit $FAIL
