#!/usr/bin/env bash
# PHASE 9 — PAM LIMITS APPLICABILITY & PROCESS CONSTRAINT SCOPE MICRO-HARDENING, sección 42/11/38.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
D="$ROOT/docs/OS_READONLY_COLLECTOR_MODEL.md"
FX="$ROOT/tests/fixtures/ol8-pam-include-chain.yaml"

[ -f "$D" ] || { echo "[FAIL] falta $D"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta $FX"; exit 1; }
grep -qi 'sigue el grafo de .include./.substack.' "$D" && echo "[PASS] declara la resolución de include/substack" || { echo "[FAIL] falta la resolución de includes"; FAIL=1; }
grep -qi 'max_depth.\?/.\?visited set' "$D" && echo "[PASS] declara protección contra loops de include (max_depth/visited set)" || { echo "[FAIL] falta la protección de loops"; FAIL=1; }
grep -q 'pam_limits_module_present: true' "$FX" && echo "[PASS] fixture confirma el módulo vía include chain" || { echo "[FAIL] falta el resultado en la fixture"; FAIL=1; }
exit $FAIL
