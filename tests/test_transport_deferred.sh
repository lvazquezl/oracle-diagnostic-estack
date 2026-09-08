#!/usr/bin/env bash
# dataguard/transport distingue DEFERRED deliberado de un error real.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/dataguard/transport/SKILL.md"

grep -q 'DEFERRED' "$S" && echo "[PASS] transport reconoce DEFERRED" || { echo "[FAIL] falta DEFERRED"; FAIL=1; }
grep -qi 'deliberadamente' "$S" && echo "[PASS] distingue DEFERRED deliberado de error" || { echo "[FAIL] falta la distinción"; FAIL=1; }

exit $FAIL
