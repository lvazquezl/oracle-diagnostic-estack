#!/usr/bin/env bash
# Valida que todo workflow activo declare Minimum agents, Optional agents y Activation conditions.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in "$ROOT"/workflows/*.md; do
  base=$(basename "$f")
  [ "$base" = "_WORKFLOW_CONTRACT_TEMPLATE.md" ] && continue
  ok=1
  for section in "# Minimum agents" "# Optional agents" "# Activation conditions" "# Stop conditions"; do
    if ! grep -q "^$section" "$f"; then
      echo "[FAIL] $f no declara '$section'"
      ok=0
      FAIL=1
    fi
  done
  [ $ok -eq 1 ] && echo "[PASS] $f declara activación mínima completa"
done

exit $FAIL
