#!/usr/bin/env bash
# dataguard/failover-readiness calcula data_loss_exposure explícitamente; fixture existe.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/dataguard/failover-readiness/SKILL.md"

grep -q 'data_loss_exposure' "$S" && echo "[PASS] declara data_loss_exposure" || { echo "[FAIL] falta data_loss_exposure"; FAIL=1; }
grep -qi 'nunca se omite este cálculo' "$S" && echo "[PASS] nunca omite el cálculo" || { echo "[FAIL] falta la regla"; FAIL=1; }
[ -f "$ROOT/tests/fixtures/19c-failover-exposure.yaml" ] && echo "[PASS] fixture failover-exposure existe" || { echo "[FAIL] falta fixture"; FAIL=1; }

exit $FAIL
