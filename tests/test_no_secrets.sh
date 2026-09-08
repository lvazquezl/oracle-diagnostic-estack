#!/usr/bin/env bash
# Ningún artefacto Data Guard expone passwords/wallets/credenciales (# 52).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
PATTERN='password\s*=|passwd\s*=|IDENTIFIED BY'

for f in $(find "$ROOT/queries/dataguard" "$ROOT/skills/dataguard" "$ROOT/parsers/dataguard" -type f 2>/dev/null) "$ROOT/docs/DATAGUARD_BROKER_READONLY_COLLECTORS.md"; do
  [ -f "$f" ] || continue
  if grep -Eiq "$PATTERN" "$f"; then
    echo "[FAIL] $f contiene un patrón de credencial"
    FAIL=1
  fi
done

grep -qi 'Nunca exponer credenciales embebidas' "$ROOT/skills/dataguard/archive-destinations/SKILL.md" \
  && echo "[PASS] archive-destinations bloquea credenciales embebidas explícitamente" \
  || { echo "[FAIL] falta la prohibición explícita"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Ningún artefacto Data Guard expone credenciales"
exit $FAIL
