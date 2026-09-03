#!/usr/bin/env bash
# Valida que una query CDB-only (ej. Q-CDB-PDB-STATE-001) declare container_scope: CDB_ROOT,
# nunca NON_CDB ni ANY_CONTAINER, para que no se recomiende sobre un target NON-CDB.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for name in Q-CDB-PDB-STATE-001 Q-CDB-CONTAINERS-001; do
  f=$(find "$ROOT/queries" -name "$name.md" 2>/dev/null)
  if [ -n "$f" ]; then
    if grep -q '^container_scope: CDB_ROOT$' "$f"; then
      echo "[PASS] $name declara container_scope: CDB_ROOT (no se ejecutará sobre NON-CDB)"
    else
      echo "[FAIL] $name no declara container_scope: CDB_ROOT"
      FAIL=1
    fi
  else
    echo "[FAIL] no se encontró $name.md en el catálogo (sólo en REGISTRY.md, no materializada)"
  fi
done

if grep -q 'No recomendar queries de PDB sobre 10g/11g' "$ROOT/agents/oracle-discovery-analyst/AGENT.md" 2>/dev/null || grep -qi 'multitenant.*no existe.*10g\|10g.*UNSUPPORTED' "$ROOT/policies/version-awareness-policy.md"; then
  echo "[PASS] La regla 'no recomendar CDB/PDB en versiones legacy' está documentada"
else
  echo "[FAIL] La regla 'no recomendar CDB/PDB en versiones legacy' no está documentada explícitamente"
  FAIL=1
fi

exit $FAIL
