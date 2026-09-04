#!/usr/bin/env bash
# network/remote-listener lee REMOTE_LISTENER y lo correlaciona con SCAN.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/network/remote-listener/SKILL.md"

grep -q 'REMOTE_LISTENER' "$S" && echo "[PASS] network/remote-listener lee REMOTE_LISTENER" || { echo "[FAIL] falta la referencia"; FAIL=1; }
grep -qi 'No modifica .REMOTE_LISTENER.' "$S" && echo "[PASS] prohibición explícita" || { echo "[FAIL] falta prohibición"; FAIL=1; }

exit $FAIL
