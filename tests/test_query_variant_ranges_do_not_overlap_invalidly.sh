#!/usr/bin/env bash
# Valida que las variantes de un mismo logical query no se solapen de forma invalida (el mismo
# rango de version cubierto por dos variantes distintas seria ambiguo para el Resolver).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

vernum() { local v="$1"; [ "$v" = "latest" ] && { echo 99999; return; }; local maj min; maj=$(echo "$v"|cut -d. -f1); min=$(echo "$v"|cut -d. -f2); echo $((maj*100+min)); }

for f in $(grep -rl '^variants:' "$ROOT/queries" --include='Q-*.md' 2>/dev/null); do
  # Variantes distinguidas por proposito (default/on-demand, ej. Q-DISC-ASM-001: mismo rango de
  # version, distinto cost_class) se solapan intencionalmente -- el Resolver las distingue por
  # el flag `default`, no por rango de version. No es el caso que este test valida.
  if grep -q 'on_demand_only: true' "$f"; then
    echo "[PASS] $f — solapamiento intencional (variantes por propósito/costo, no por versión — ver 'default:'/'on_demand_only:')"
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
      amin=$(vernum "${mins[$a]}"); amax=$(vernum "${maxs[$a]}")
      bmin=$(vernum "${mins[$b]}"); bmax=$(vernum "${maxs[$b]}")
      if [ "$amin" -le "$bmax" ] && [ "$bmin" -le "$amax" ]; then
        echo "[FAIL] $f — variantes #$((a+1)) [${mins[$a]}-${maxs[$a]}] y #$((b+1)) [${mins[$b]}-${maxs[$b]}] se solapan"
        ok=0; FAIL=1
      fi
    done
  done
  [ $ok -eq 1 ] && echo "[PASS] $f — rangos de variantes no se solapan"
done

exit $FAIL
