#!/usr/bin/env bash
# Valida que un target standalone no active oracle-rac-analyst: workflows/rac.md debe gatear
# explícitamente por instance_mode = rac antes de continuar.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

if grep -qi 'si es standalone' "$ROOT/workflows/rac.md" || grep -qi 'no aplica y se lo informa' "$ROOT/workflows/rac.md"; then
  echo "[PASS] workflows/rac.md se detiene explícitamente si el target no es RAC"
else
  echo "[FAIL] workflows/rac.md no gatea explícitamente contra standalone"
  FAIL=1
fi

if grep -q 'gates:' "$ROOT/workflows/rac.md" && grep -A10 '^# Gates' "$ROOT/workflows/rac.md" | grep -qi 'instance_mode'; then
  echo "[PASS] workflows/rac.md declara el gate 'architecture' evaluando instance_mode antes de activar el agente"
else
  echo "[FAIL] workflows/rac.md no declara un gate explícito de arquitectura/instance_mode"
  FAIL=1
fi

if grep -q '10g          → multitenant' "$ROOT/policies/version-awareness-policy.md" && grep -q 'Standalone            → rac/\*            → UNSUPPORTED' "$ROOT/policies/version-awareness-policy.md"; then
  echo "[PASS] policies/version-awareness-policy.md documenta Standalone -> rac/* -> UNSUPPORTED"
else
  echo "[FAIL] policies/version-awareness-policy.md no documenta Standalone -> rac/* -> UNSUPPORTED"
  FAIL=1
fi

exit $FAIL
