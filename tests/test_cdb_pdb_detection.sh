#!/usr/bin/env bash
# Valida que el modelo de discovery distinga explícitamente NON-CDB/CDB/PDB.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
F="$ROOT/skills/core/context-discovery.md"

if grep -qi 'container_mode' "$F" && grep -qi 'non_cdb' "$F" && grep -qi 'pdbs' "$F"; then
  echo "[PASS] core/context-discovery distingue non_cdb/cdb y lista PDBs"
else
  echo "[FAIL] core/context-discovery no distingue explícitamente non_cdb/cdb/PDBs"
  FAIL=1
fi

# skills/multitenant/container-state.md (Foundation) fue migrado/expandido a
# skills/multitenant/pdb-state/SKILL.md en Fase 6 -- ver skills/REGISTRY.md#multitenant.
if [ -f "$ROOT/skills/multitenant/pdb-state/SKILL.md" ] && grep -q 'status: active' "$ROOT/skills/multitenant/pdb-state/manifest.yaml"; then
  echo "[PASS] skills/multitenant/pdb-state/SKILL.md materializado y activo"
else
  echo "[FAIL] skills/multitenant/pdb-state/SKILL.md ausente o no activo"
  FAIL=1
fi

exit $FAIL
