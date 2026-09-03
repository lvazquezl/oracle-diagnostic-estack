#!/usr/bin/env bash
# Q-ORA-TEMP-001 no requirió variantes (DBA_TEMP_FREE_SPACE existe desde 10g) — este test
# confirma esa afirmación contra el dictionary, en vez de asumirla.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
DICT="$ROOT/compatibility/oracle-dictionary/views.yaml"
F="$ROOT/queries/oracle/temp/Q-ORA-TEMP-001.md"

if grep -A1 '^  DBA_TEMP_FREE_SPACE:' "$DICT" | grep -q 'min_version: all'; then
  echo "[PASS] DBA_TEMP_FREE_SPACE registrada como disponible desde 10g (min_version: all) en el dictionary"
else
  echo "[FAIL] DBA_TEMP_FREE_SPACE no está registrada como 'all' en el dictionary — Q-ORA-TEMP-001 debería tener variantes"
  FAIL=1
fi

if grep -q '^variants:' "$F"; then
  echo "[FAIL] Q-ORA-TEMP-001 declara variants: explícitas — inconsistente con 'DBA_TEMP_FREE_SPACE min_version: all'"
  FAIL=1
else
  echo "[PASS] Q-ORA-TEMP-001 usa implicit_full_range (10g–23ai), consistente con la disponibilidad real de DBA_TEMP_FREE_SPACE"
fi

exit $FAIL
