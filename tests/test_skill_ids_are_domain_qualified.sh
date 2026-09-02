#!/usr/bin/env bash
# Valida que todo skill_id sea dominio/skill (nunca un nombre corto suelto), tanto en el registro
# como en el campo `id:` de cada skill materializado.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
QUALIFIED='^[a-z0-9_-]+/[a-z0-9_*/-]+$'

ids=$(grep -oE '^\| `[a-z0-9_-]+/[a-z0-9_*/-]+`' "$ROOT/skills/REGISTRY.md" | grep -oE '`[a-z0-9_-]+/[a-z0-9_*/-]+`' | tr -d '`')
while IFS= read -r id; do
  [ -z "$id" ] && continue
  if ! echo "$id" | grep -Eq "$QUALIFIED"; then
    echo "[FAIL] '$id' en skills/REGISTRY.md no está domain-qualified"
    FAIL=1
  fi
done <<< "$ids"
[ $FAIL -eq 0 ] && echo "[PASS] Todos los skill_id en skills/REGISTRY.md están domain-qualified"

FAIL2=0
for f in $(grep -rl 'status: active' "$ROOT/skills" --include='*.md'); do
  base=$(basename "$f")
  [ "$base" = "_SKILL_CONTRACT_TEMPLATE.md" ] && continue
  id=$(awk -F': ' '/^id: /{print $2; exit}' "$f")
  if ! echo "$id" | grep -Eq "$QUALIFIED"; then
    echo "[FAIL] $f declara id '$id' que no está domain-qualified"
    FAIL2=1
  fi
done
[ $FAIL2 -eq 0 ] && echo "[PASS] Todo skill materializado declara 'id:' domain-qualified en su frontmatter"

[ $FAIL -eq 0 ] && [ $FAIL2 -eq 0 ]
