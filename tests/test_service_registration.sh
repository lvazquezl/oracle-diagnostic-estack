#!/usr/bin/env bash
# network/service-registration compara declarado vs. registrado, candidato a TNS-12514.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/network/service-registration/SKILL.md"
FX="$ROOT/tests/fixtures/19c-listener-registration-issue.yaml"

grep -qi 'TNS-12514' "$S" && echo "[PASS] service-registration correlaciona con TNS-12514" || { echo "[FAIL] falta la correlación"; FAIL=1; }
[ -f "$FX" ] && echo "[PASS] fixture de escenario de registro existe" || { echo "[FAIL] falta el fixture"; FAIL=1; }

exit $FAIL
