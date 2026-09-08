#!/usr/bin/env bash
# Toda query dataguard declara supported_oracle_versions explícito, sin asumir 'latest' automático.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in $(find "$ROOT/queries/dataguard" -name 'Q-*.md'); do
  grep -q '^supported_oracle_versions:' "$f" && echo "[PASS] $(basename "$f") declara supported_oracle_versions" || { echo "[FAIL] $(basename "$f") no declara supported_oracle_versions"; FAIL=1; }
done

exit $FAIL
