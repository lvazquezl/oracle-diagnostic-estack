#!/usr/bin/env bash
# dataguard/archive-gaps clasifica RECEIVED_NOT_APPLIED como categoría distinta de TRANSPORT_GAP.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/dataguard/archive-gaps/SKILL.md"

grep -q 'RECEIVED_NOT_APPLIED' "$S" && echo "[PASS] archive-gaps declara RECEIVED_NOT_APPLIED" || { echo "[FAIL] falta la clasificación"; FAIL=1; }
grep -qi 'correlacionar con .dataguard/apply' "$S" && echo "[PASS] correlaciona con dataguard/apply" || { echo "[FAIL] falta correlación"; FAIL=1; }

exit $FAIL
