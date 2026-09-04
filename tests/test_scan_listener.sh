#!/usr/bin/env bash
# network/scan diferencia recurso Clusterware (rac/gi-scan) de conectividad, nunca lo duplica.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/network/scan/SKILL.md"

grep -qi 'estado del recurso Clusterware.*es responsabilidad de .rac/gi-scan' "$S" \
  && echo "[PASS] network/scan delega estado de recurso a rac/gi-scan" \
  || { echo "[FAIL] falta la delegación explícita"; FAIL=1; }
grep -q 'srvctl config scan' "$S" && echo "[PASS] usa srvctl config scan" || { echo "[FAIL] falta la referencia al collector"; FAIL=1; }

exit $FAIL
