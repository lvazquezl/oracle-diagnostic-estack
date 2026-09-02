#!/usr/bin/env bash
# Valida que todo skill_id en skills/REGISTRY.md sea globalmente unico (no solo dentro de su dominio).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

# Sólo filas de tabla de registro (columna skill_id), no menciones en prosa/ejemplos.
ids=$(grep -oE '^\| `[a-z0-9_-]+/[a-z0-9_*/-]+`' "$ROOT/skills/REGISTRY.md" | grep -oE '`[a-z0-9_-]+/[a-z0-9_*/-]+`' | tr -d '`' | sort)
dupes=$(echo "$ids" | uniq -d)

if [ -n "$dupes" ]; then
  echo "[FAIL] skill_id duplicado(s) en skills/REGISTRY.md:"
  echo "$dupes"
  FAIL=1
else
  count=$(echo "$ids" | grep -c . || true)
  echo "[PASS] $count skill_id listados en skills/REGISTRY.md, todos unicos globalmente"
fi

exit $FAIL
