#!/usr/bin/env bash
# network/local-listener lee LOCAL_LISTENER y lo correlaciona con el listener real.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/network/local-listener/SKILL.md"

grep -q 'LOCAL_LISTENER' "$S" && echo "[PASS] network/local-listener lee LOCAL_LISTENER" || { echo "[FAIL] falta la referencia"; FAIL=1; }
grep -qi 'No modifica .LOCAL_LISTENER.' "$S" && echo "[PASS] prohibición explícita" || { echo "[FAIL] falta prohibición"; FAIL=1; }

exit $FAIL
