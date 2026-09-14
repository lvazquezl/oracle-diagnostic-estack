#!/usr/bin/env bash
# Valida que las variantes de un mismo logical query no se solapen de forma invalida (el mismo
# rango de version cubierto por dos variantes distintas seria ambiguo para el Resolver).
#
# PHASE 6 — VERSION RESOLVER CONSOLIDATION FINALIZATION (# 6, # 16 del prompt): usa
# scripts/lib/version.sh en vez de un vernum() local.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/version.sh"
FAIL=0

for f in $(grep -rl '^variants:' "$ROOT/queries" --include='Q-*.md' 2>/dev/null); do
  # Variantes distinguidas por proposito (default/on-demand, ej. Q-DISC-ASM-001: mismo rango de
  # version, distinto cost_class) se solapan intencionalmente -- el Resolver las distingue por
  # el flag `default`, no por rango de version. No es el caso que este test valida.
  if grep -q 'on_demand_only: true' "$f"; then
    echo "[PASS] $f — solapamiento intencional (variantes por propósito/costo, no por versión — ver 'default:'/'on_demand_only:')"
    continue
  fi
  # Variantes distinguidas por privilegio disponible en la cuenta que ejecuta (Fase 8, ej.
  # Q-SEC-PASSWORD-VERIFY-SOURCE-001: DBA_SOURCE vs. ALL_SOURCE, mismo rango de version) se
  # solapan intencionalmente -- el Resolver las distingue por el flag `privilege_fallback`, no
  # por rango de version. Ver docs/QUERY_VARIANTS.md#privilege-scope-variants.
  if grep -q 'privilege_fallback: true' "$f"; then
    echo "[PASS] $f — solapamiento intencional (variantes por privilegio disponible, no por versión — ver 'default:'/'privilege_fallback:')"
    continue
  fi
  ranges=$(grep -oE 'oracle_versions: \{min: "[^"]+", max: [^}]+\}' "$f")
  mins=(); maxs=()
  while IFS= read -r r; do
    m=$(echo "$r" | grep -oE 'min: "[^"]+"' | grep -oE '"[^"]+"' | tr -d '"')
    x=$(echo "$r" | grep -oE 'max: [^}]+' | sed -E 's/max: *"?//; s/"?$//')
    mins+=("$m"); maxs+=("$x")
  done <<< "$ranges"
  n=${#mins[@]}
  ok=1
  for ((a=0; a<n; a++)); do
    for ((b=a+1; b<n; b++)); do
      if version_lte "${mins[$a]}" "${maxs[$b]}" && version_lte "${mins[$b]}" "${maxs[$a]}"; then
        echo "[FAIL] $f — variantes #$((a+1)) [${mins[$a]}-${maxs[$a]}] y #$((b+1)) [${mins[$b]}-${maxs[$b]}] se solapan"
        ok=0; FAIL=1
      fi
    done
  done
  [ $ok -eq 1 ] && echo "[PASS] $f — rangos de variantes no se solapan"
done

exit $FAIL
