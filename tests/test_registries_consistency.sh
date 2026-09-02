#!/usr/bin/env bash
# Valida que todo agente listado en agents/REGISTRY.md tenga manifest, y que todo skill marcado
# **active** en skills/REGISTRY.md tenga archivo materializado con status: active.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

# Agentes: extraer ids de la tabla (columna entre backticks) y verificar archivo
while IFS= read -r id; do
  [ -z "$id" ] && continue
  if [ -f "$ROOT/agents/$id.md" ]; then
    echo "[PASS] agents/$id.md existe"
  else
    echo "[FAIL] agents/REGISTRY.md referencia '$id' pero agents/$id.md no existe"
    FAIL=1
  fi
done < <(grep -oE '^\| `[a-z-]+`' "$ROOT/agents/REGISTRY.md" | sed -E 's/^\| `//; s/`$//')

# Skills marcados active en el registro deben tener un archivo con status: active
while IFS= read -r path; do
  [ -z "$path" ] && continue
  full="$ROOT/skills/$path"
  if [ -f "$full" ] && grep -q '^status: active' "$full"; then
    echo "[PASS] skills/$path materializado y activo"
  else
    echo "[FAIL] skills/REGISTRY.md marca '$path' como active pero el archivo no existe o no tiene status: active"
    FAIL=1
  fi
done < <(grep -oE '\[([a-z0-9_/.-]+\.md)\]' "$ROOT/skills/REGISTRY.md" | tr -d '[]')

exit $FAIL
