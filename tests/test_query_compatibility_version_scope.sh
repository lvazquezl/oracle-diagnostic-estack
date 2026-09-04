#!/usr/bin/env bash
# Valida que una query 11gR2-only (ej. Q-DISC-RAC-001, Q-RAC-SESSION-DIST-001) declare
# explícitamente su versión mínima y NO liste versiones anteriores como soportadas.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

F="$ROOT/queries/oracle/discovery/Q-DISC-RAC-001.md"
if grep -q '^supported_oracle_versions: \[11gR2' "$F" && ! grep -qE '^supported_oracle_versions: \[(10g|11g,)' "$F"; then
  echo "[PASS] Q-DISC-RAC-001 declara 11gR2 como mínimo, sin incluir 10g/11g genérico"
else
  echo "[FAIL] Q-DISC-RAC-001 no acota correctamente su versión mínima"
  FAIL=1
fi

F2="$ROOT/queries/rac/Q-RAC-SESSION-DIST-001.md"
if [ -f "$F2" ] && grep -q '^supported_oracle_versions: \[11gR2' "$F2"; then
  echo "[PASS] Q-RAC-SESSION-DIST-001 declara 11gR2 como mínimo"
else
  echo "[FAIL] Q-RAC-SESSION-DIST-001 no declara 11gR2 como mínimo"
  FAIL=1
fi

if grep -qi '10g/11gR1 (RAC pre-11gR2) esta query no está certificada' "$ROOT/queries/oracle/discovery/Q-DISC-RAC-001.md" 2>/dev/null || grep -qi 'no certificado para 10g' "$ROOT/queries/oracle/discovery/Q-DISC-RAC-001.md"; then
  echo "[PASS] Q-DISC-RAC-001 declara explícitamente la no-certificación en 10g/11gR1"
else
  echo "[FAIL] Q-DISC-RAC-001 no declara explícitamente la no-certificación en versiones anteriores"
  FAIL=1
fi

exit $FAIL
