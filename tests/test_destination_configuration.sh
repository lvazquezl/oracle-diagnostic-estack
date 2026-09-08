#!/usr/bin/env bash
# dataguard/archive-destinations extrae SERVICE/SYNC-ASYNC/AFFIRM/VALID_FOR/DB_UNIQUE_NAME etc.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/dataguard/archive-destinations/SKILL.md"

for field in service mode affirm valid_for db_unique_name net_timeout; do
  grep -qi "$field" "$S" && echo "[PASS] archive-destinations declara $field" || { echo "[FAIL] falta $field"; FAIL=1; }
done
grep -qi 'nunca exponer credenciales' "$S" && echo "[PASS] prohibición explícita de exponer credenciales" || { echo "[FAIL] falta la prohibición"; FAIL=1; }

exit $FAIL
