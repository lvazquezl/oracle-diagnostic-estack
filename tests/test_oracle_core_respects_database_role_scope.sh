#!/usr/bin/env bash
# Valida que toda query Oracle Core declare database_role_scope válido, y que las queries
# claramente ligadas a actividad de escritura (redo/archive/undo/jobs) sean PRIMARY, no ANY.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
VALID='^database_role_scope: (PRIMARY|STANDBY|ANY|NOT_APPLICABLE)$'

for f in $(find "$ROOT/queries/oracle" -name 'Q-*.md'); do
  line=$(grep '^database_role_scope:' "$f" || true)
  if [ -z "$line" ] || ! echo "$line" | grep -Eq "$VALID"; then
    echo "[FAIL] $f no declara database_role_scope válido"
    FAIL=1
  fi
done

for name in Q-ORA-REDO-001 Q-ORA-ARCHIVE-001 Q-ORA-UNDO-001 Q-ORA-JOBS-SUMMARY-001; do
  f=$(find "$ROOT/queries/oracle" -name "$name.md")
  if [ -n "$f" ] && grep -q '^database_role_scope: PRIMARY$' "$f"; then
    echo "[PASS] $name está correctamente restringida a PRIMARY"
  else
    echo "[FAIL] $name debería estar restringida a PRIMARY (actividad de escritura activa)"
    FAIL=1
  fi
done

exit $FAIL
