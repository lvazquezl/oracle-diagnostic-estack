#!/usr/bin/env bash
# dataguard/archive-gaps declara las 5 clasificaciones completas (# 58), nunca mezcladas.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/dataguard/archive-gaps/SKILL.md"

for cls in TRANSPORT_GAP RECEIVED_NOT_APPLIED THREAD_SPECIFIC_GAP TEMPORARY_GAP UNKNOWN_GAP; do
  grep -q "$cls" "$S" && echo "[PASS] archive-gaps declara $cls" || { echo "[FAIL] falta $cls"; FAIL=1; }
done
grep -qi 'Nunca mezclar clasificaciones' "$S" && echo "[PASS] nunca mezcla clasificaciones" || { echo "[FAIL] falta la regla"; FAIL=1; }

exit $FAIL
