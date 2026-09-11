#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 42.
# Toda query Q-RMAN-*.md debe declarar variantes con max explícito (nunca "latest") y min real.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/version.sh"
FAIL=0

for f in "$ROOT"/queries/rman/Q-*.md; do
  name=$(basename "$f")
  if ! grep -q '^variants:' "$f"; then
    echo "[FAIL] $name no declara variants:"
    FAIL=1
    continue
  fi
  if grep -qE 'max: *latest' "$f"; then
    echo "[FAIL] $name declara max: latest — prohibido (# 5 del prompt de Fase 7, future versions no se auto-certifican)"
    FAIL=1
  else
    echo "[PASS] $name nunca declara max: latest"
  fi
  mins=$(grep -oE 'min: "[^"]+"' "$f" | grep -oE '"[^"]+"' | tr -d '"')
  while IFS= read -r m; do
    [ -z "$m" ] && continue
    read -ra t <<< "$(normalize_oracle_version "$m")"
    if [ "${t[0]}" -lt 10 ]; then
      echo "[FAIL] $name declara min '$m' por debajo del piso certificado 10g"
      FAIL=1
    fi
  done <<< "$mins"
done

[ $FAIL -eq 0 ] && echo "[PASS] Todas las queries Q-RMAN-* declaran rango de versión real, sin 'latest'"
exit $FAIL
