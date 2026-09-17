#!/usr/bin/env bash
# Valida que, para cada fixture (tests/fixtures/*.yaml), el Query Variant Resolver seleccione
# una variante cuyas columnas version-gated sean consistentes con compatibility_schema.available_columns
# de esa fixture (seccion 26 del prompt de Compatibility Hardening: "Los tests deberan validar la
# query seleccionada contra ese fixture").
#
# PHASE 6 — VERSION RESOLVER CONSOLIDATION FINALIZATION (# 6, # 17 del prompt): usa
# scripts/lib/version.sh en vez de un vernum() local.
#
# PERFORMANCE HARDENING (post Fase 10, sin cambio de criterio de aprobacion/rechazo): la version
# anterior re-parseaba los ~39 archivos de query con variantes por cada fixture (fixtures x queries
# x rangos), miles de sub-procesos grep/awk repetidos -- impracticamente lento en Windows/Cygwin
# por el overhead de fork/exec (confirmado por CPU-time activo pero progreso de horas en una sola
# ejecucion, con ~165 fixtures acumuladas a esta altura del proyecto). Reescrito en dos pasadas:
# (1) UNA sola vez, por archivo de query, se extraen sus rangos y el set de columnas riesgosas
#     presentes en cada variante -- unico uso de grep/awk/sed de todo el script, ~39 archivos, no
#     repetido por fixture.
# (2) Por cada fixture, la resolucion de variante usa comparacion de strings zero-padded
#     (equivalente a comparar tuplas de version) en bash puro, con memoizacion de
#     normalize_oracle_version por string de version (evita re-invocarla, que forkea, para el mismo
#     valor repetido) -- ningun proceso externo se spawnea en el hot loop fixture x query x rango.
# Mismo comportamiento observable (mismos PASS/FAIL) que la version original; sólo cambia el costo.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/version.sh"
FAIL=0

# pattern (grep -Ei contra el bloque SQL de la variante) : colkey (clave literal en
# compatibility_schema.available_columns de la fixture)
RISKY_COLUMNS=("version_full:V\$INSTANCE.version_full" "\bcdb\b:V\$DATABASE.cdb" "con_id:V\$ACTIVE_INSTANCES.con_id" "instance_role:V\$INSTANCE.instance_role")

# --- Normalizacion memoizada: convierte un string de version en una clave comparable
# (5 componentes zero-padded a 6 digitos, concatenados) para poder usar comparacion de strings
# ([[ a < b ]], lexicografica = numerica cuando el ancho es fijo) sin invocar funciones que forkean
# en el hot loop. normalize_oracle_version() nunca devuelve componentes > 999999 (el sentinel de
# "latest"/"all" ya usa exactamente ese valor), asi que %06d nunca trunca. ---
declare -A NORM_CACHE
norm_key() {
  local v="$1"
  if [ -z "${NORM_CACHE[$v]+x}" ]; then
    local raw; raw="$(normalize_oracle_version "$v")"
    local -a parts; read -ra parts <<< "$raw"
    NORM_CACHE["$v"]=$(printf '%06d%06d%06d%06d%06d' "${parts[0]:-0}" "${parts[1]:-0}" "${parts[2]:-0}" "${parts[3]:-0}" "${parts[4]:-0}")
  fi
  printf '%s' "${NORM_CACHE[$v]}"
}

# --- Pase 1: pre-computar, por archivo de query con variantes, sus rangos ya normalizados y las
# columnas riesgosas presentes en cada variante. ---
declare -a QFILES=()
declare -A QID
declare -A NRANGES
declare -A RANGE_MIN_KEY
declare -A RANGE_MAX_KEY
declare -A VARCOLS

for f in $(grep -rl '^variants:' "$ROOT/queries" --include='Q-*.md' 2>/dev/null); do
  QFILES+=("$f")
  QID["$f"]=$(grep -m1 '^query_id:' "$f" | awk '{print $2}')
  ranges=$(grep -oE 'oracle_versions: \{min: "[^"]+", max: [^}]+\}' "$f")
  i=0
  while IFS= read -r r; do
    [ -z "$r" ] && continue
    i=$((i+1))
    m=$(echo "$r" | grep -oE 'min: "[^"]+"' | grep -oE '"[^"]+"' | tr -d '"')
    x=$(echo "$r" | grep -oE 'max: [^}]+' | sed -E 's/max: *"?//; s/"?$//')
    RANGE_MIN_KEY["$f,$i"]="$(norm_key "$m")"
    RANGE_MAX_KEY["$f,$i"]="$(norm_key "$x")"

    block=$(awk -v n="$i" '/```sql/{c++} c==n && /```sql/{flag=1;next} flag && /```/{flag=0} flag' "$f" | sed -E 's/--.*$//')
    cols=""
    for entry in "${RISKY_COLUMNS[@]}"; do
      col="${entry%%:*}"
      colkey="${entry##*:}"
      if echo "$block" | grep -Eiq "$col"; then
        cols="$cols|$colkey"
      fi
    done
    VARCOLS["$f,$i"]="$cols"
  done <<< "$ranges"
  NRANGES["$f"]=$i
done

# --- Pase 2: por cada fixture, resolver la variante y verificar sus columnas riesgosas contra
# compatibility_schema.available_columns -- sin subprocesos externos en este loop. ---
for fx in "$ROOT"/tests/fixtures/*.yaml; do
  fx_name=$(basename "$fx")
  content=$(<"$fx")

  # Fixtures del dominio OS (Fase 9, os/*) no versionan por Oracle version -- oracle_version/
  # compatibility_schema no aplican, el Query Variant Resolver no interviene en su dominio (evidencia
  # de collectors semanticos, no queries SQL). Se marcan por el top-level os_target: en vez de
  # oracle_version:, y quedan fuera de alcance de este test, no un fallo.
  if [[ "$content" == os_target:* || "$content" == *$'\n'"os_target:"* ]] && [[ "$content" != *"oracle_version:"* ]]; then
    continue
  fi

  # Fixtures del dominio Capacity (Fase 10, capacity/*) tampoco versionan por Oracle version --
  # son series sinteticas de capacidad (target_id/technology/resource_type), no evidencia SQL. Se
  # marcan por el top-level capacity_target: en vez de oracle_version:, y quedan fuera de alcance
  # de este test, no un fallo -- mismo patron que el skip de os_target: arriba.
  if [[ "$content" == capacity_target:* || "$content" == *$'\n'"capacity_target:"* ]] && [[ "$content" != *"oracle_version:"* ]]; then
    continue
  fi

  if [[ "$content" != compatibility_schema:* && "$content" != *$'\n'"compatibility_schema:"* ]]; then
    echo "[FAIL] $fx_name — sin compatibility_schema (seccion 26)"
    FAIL=1
    continue
  fi

  ov_line=""
  while IFS= read -r line; do
    if [[ "$line" == *"oracle_version:"* ]]; then
      ov_line="$line"
      break
    fi
  done <<< "$content"

  tmajor=""; tminor=""
  [[ "$ov_line" =~ major:\ ([0-9]+) ]] && tmajor="${BASH_REMATCH[1]}"
  [[ "$ov_line" =~ minor:\ ([0-9]+) ]] && tminor="${BASH_REMATCH[1]}"
  target="${tmajor}.${tminor}"
  tkey="$(norm_key "$target")"

  for f in "${QFILES[@]}"; do
    qid="${QID[$f]}"
    n="${NRANGES[$f]}"
    resolved_i=0
    for ((i = 1; i <= n; i++)); do
      minkey="${RANGE_MIN_KEY[$f,$i]}"
      maxkey="${RANGE_MAX_KEY[$f,$i]}"
      if [[ ( "$tkey" > "$minkey" || "$tkey" == "$minkey" ) && ( "$tkey" < "$maxkey" || "$tkey" == "$maxkey" ) ]]; then
        resolved_i=$i
        break
      fi
    done

    [ "$resolved_i" -eq 0 ] && continue

    cols="${VARCOLS[$f,$resolved_i]}"
    [ -z "$cols" ] && continue

    IFS='|' read -ra colarr <<< "$cols"
    for colkey in "${colarr[@]}"; do
      [ -z "$colkey" ] && continue
      if [[ "$content" == *"\"$colkey\":"* ]]; then
        rest="${content#*\"$colkey\":}"
        if [[ "$rest" =~ ^[[:space:]]*(true|false) ]]; then
          avail="${BASH_REMATCH[1]}"
          if [ "$avail" = "false" ]; then
            echo "[FAIL] $fx_name / $qid — variante resuelta (#$resolved_i) usa columna '$colkey' pero la fixture la declara no disponible"
            FAIL=1
          fi
        fi
      fi
    done
  done
done

[ $FAIL -eq 0 ] && echo "[PASS] Para cada fixture, la variante resuelta por el Query Variant Resolver es consistente con su compatibility_schema.available_columns"

exit $FAIL
