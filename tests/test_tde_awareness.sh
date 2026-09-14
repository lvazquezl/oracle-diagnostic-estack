#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 69/31.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/security/tde-awareness/SKILL.md"

for verb in "OPEN/CLOSE KEYSTORE" "SET KEY" "ROTATE KEY" "CREATE KEYSTORE"; do
  grep -qF "$verb" "$S" && echo "[PASS] documenta prohibición de $verb" || { echo "[FAIL] falta $verb"; FAIL=1; }
done

grep -A3 "^# Forbidden operations" "$S" | grep -qi "ADMINISTER KEY MANAGEMENT" \
  && echo "[PASS] Forbidden operations prohíbe ADMINISTER KEY MANAGEMENT" \
  || { echo "[FAIL] falta la prohibición en Forbidden operations"; FAIL=1; }

for fx in 19c-tde-enabled.yaml 19c-tde-absent.yaml; do
  [ -f "$ROOT/tests/fixtures/$fx" ] && echo "[PASS] fixture $fx existe" || { echo "[FAIL] falta fixture $fx"; FAIL=1; }
done

exit $FAIL
