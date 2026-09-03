#!/usr/bin/env bash
# Valida que la lógica de detección de PDB (oracle-discovery-analyst) nunca liste PDBs cuando
# multitenant_mode = non_cdb -- el container detection debe bloquear explícitamente ese caso.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
AGENT="$ROOT/agents/oracle-discovery-analyst/AGENT.md"

if grep -q 'En 10g/11g, `multitenant_mode` es siempre `non_cdb` sin necesidad de leer la columna' "$AGENT"; then
  echo "[PASS] oracle-discovery-analyst declara explícitamente que 10g/11g nunca listan PDBs"
else
  echo "[FAIL] oracle-discovery-analyst no bloquea explícitamente la detección de PDB en 10g/11g"
  FAIL=1
fi

if grep -q 'container.type.*non_cdb.*multitenant_mode = non_cdb' "$AGENT"; then
  echo "[PASS] container.type se deriva correctamente a non_cdb cuando multitenant_mode = non_cdb"
else
  echo "[FAIL] no se encontró la regla de derivación container.type = non_cdb"
  FAIL=1
fi

exit $FAIL
