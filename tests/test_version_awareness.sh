#!/usr/bin/env bash
# Valida que todo skill/query activo declare versiones Oracle soportadas.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in $(grep -rl 'status: active' "$ROOT/skills" --include='*.md'); do
  if ! grep -q '^# Supported Oracle versions' "$f"; then
    echo "[FAIL] $f (active) no declara '# Supported Oracle versions'"
    FAIL=1
  fi
done

for f in $(find "$ROOT/queries" -name 'Q-*.md'); do
  [ -f "$f" ] || continue
  if ! grep -q '^supported_oracle_versions:' "$f"; then
    echo "[FAIL] $f no declara 'supported_oracle_versions:' en frontmatter (Query Contract v2)"
    FAIL=1
  fi
done

[ $FAIL -eq 0 ] && echo "[PASS] Todo skill/query activo declara versiones soportadas"
exit $FAIL
