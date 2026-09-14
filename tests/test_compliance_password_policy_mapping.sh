#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 71/46.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
FX="$ROOT/tests/fixtures/19c-compliance-partial.yaml"

[ -f "$FX" ] && echo "[PASS] fixture de compliance mapping con password policy existe" || { echo "[FAIL] falta la fixture"; FAIL=1; }
grep -qi "framework: \"INTERNAL\"\|INTERNAL" "$FX" && echo "[PASS] fixture referencia framework INTERNAL" || { echo "[FAIL] falta el framework"; FAIL=1; }
grep -q "PWD-001\|password_life_time" "$FX" && echo "[PASS] fixture mapea un control de password policy" || { echo "[FAIL] falta el control de password"; FAIL=1; }

exit $FAIL
