#!/usr/bin/env bash
# SQL Static Validator (sección 23 del prompt de Compatibility Hardening; endurecido en
# PHASE 5 — DATA GUARD COMPATIBILITY & QUERY CERTIFICATION HARDENING, secciones 7-9).
# No es un parser SQL completo: usa metadata estructurada (compatibility/oracle-dictionary/views.yaml)
# y valida DOS cosas independientes sobre cada bloque SQL certificado (variante o rango implícito):
#   1) columnas version-gated conocidas usadas sin guardia de versión (chequeo original);
#   2) columnas que NO EXISTEN en absoluto en la vista referenciada, para cualquier vista que el
#      dictionary modele con un bloque `columns:` (chequeo nuevo — la causa raíz de que
#      Q-DG-ROLE-001 v1.0 pudiera seleccionar V$DATABASE.LOG_ARCHIVE_CONFIG, que no existe, sin que
#      ningún test lo detectara: sólo se validaba version-gating, nunca existencia de columna).
# El chequeo (2) resuelve alias básicos (`SELECT d.col FROM v$archive_dest d`) y JOIN/comma-join,
# pero se abstiene deliberadamente (skip, no falso positivo) ante subqueries anidadas en el SELECT
# — eso sería empezar a construir un parser SQL completo, explícitamente fuera de alcance (# 8).
#
# NOTA DE RENDIMIENTO: este test recorre ~62 archivos de queries certificadas con múltiples
# invocaciones de awk/grep/sed por bloque. En Windows Git Bash el costo de spawnear procesos es
# alto (medido: ~150-400ms por pipe simple) y el runtime observado es de varios minutos (~15) —
# no es un hang. Ya está optimizado para evitar el peor caso (sin python3, con cacheo de columnas
# por vista y un filtro rápido de fixed-string antes de la extracción completa); un test similar
# de fases anteriores (`test_fixture_query_variant_resolution.sh`) tiene el mismo perfil y ya fue
# aceptado como tolerable en este proyecto por el mismo motivo.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DICT="$ROOT/compatibility/oracle-dictionary/views.yaml"
FAIL=0

# PHASE 6 — FINAL PDB IDENTITY & PATCH-LEVEL RESOLVER HARDENING (# 22 del prompt): la comparación
# de versión ya no se reimplementa localmente (vernum()/vernum3() de hardenings anteriores) — usa
# la misma librería compartida que tests/test_query_variant_resolver_{10g,11g}.sh y las queries de
# saved-state, patch-level-aware desde el día uno (scripts/lib/version.sh).
source "$ROOT/scripts/lib/version.sh"

# Nombres de vista (y su contraparte GV$, si aplica) marcadas columns_exhaustive:true — usado como
# filtro rápido de "vale la pena analizar este bloque" antes de la extracción completa (rendimiento).
# Comparación por texto literal (grep -F), no regex — evita problemas de escapado de "$".
EXHAUSTIVE_VIEWS_FILE="$(mktemp)"
trap 'rm -f "$EXHAUSTIVE_VIEWS_FILE"' EXIT
awk '
  /^  [A-Za-z$#0-9_]+:[ \t]*$/ {
    line=$0; sub(/^  /,"",line); sub(/:[ \t]*$/,"",line); cur=line; next
  }
  /^    columns_exhaustive:[ \t]*true[ \t]*$/ {
    print cur
    if (cur ~ /^V\$/) {
      base=cur; sub(/^V\$/,"",base)
      print "GV$" base
    }
  }
' "$DICT" > "$EXHAUSTIVE_VIEWS_FILE"

# PHASE 8 — SECURITY QUERY COMPATIBILITY, ORACLE NET EVIDENCE & STATIC VALIDATOR HARDENING (# 13,
# # 14 del prompt): causa raíz real de que Q-SEC-DEFAULT-ACCOUNTS-001 pudiera seleccionar
# DBA_USERS.ORACLE_MAINTAINED (min_version real "12.1") desde un bloque implicit_full_range con
# min declarado "11.0" sin que ningún chequeo lo detectara — extract_aliases() (abajo) sólo
# reconocía como "objeto de vista" un token que contuviera literalmente "$", así que CUALQUIER
# objeto del dictionary sin "$" (DBA_*, CDB_*, ALL_*, USER_*, ROLE_*, AUDIT_*, UNIFIED_*,
# REDACTION_*, ...) nunca entraba en alias_map y por lo tanto nunca se validaba ni por existencia
# de columna (Chequeo 2) ni por version-gating (Chequeo 3). Fix dictionary-driven (# 14): en vez
# de hardcodear prefixes, se construye el conjunto COMPLETO de nombres de objeto de nivel superior
# registrados en el dictionary (exhaustive o no — igual que el comportamiento ya existente para
# objetos "$" no registrados, que se capturan pero no producen hallazgo si no están en el
# dictionary) y extract_aliases() reconoce un token como candidato a vista si contiene "$" (compat
# histórico, sin cambios) O si su forma en minúsculas coincide EXACTAMENTE con un objeto
# registrado — nunca por substring, para no confundir DBA_USERS con DBA_USERS_WITH_DEFPWD.
declare -A ALL_DICT_OBJECTS
while IFS= read -r obj; do
  [ -z "$obj" ] && continue
  ALL_DICT_OBJECTS["$obj"]=1
done < <(awk '
  /^  [A-Za-z$#0-9_]+:[ \t]*$/ {
    line=$0; sub(/^  /,"",line); sub(/:[ \t]*$/,"",line)
    print tolower(line)
    if (line ~ /^V\$/) {
      base=line; sub(/^V\$/,"",base)
      print tolower("GV$" base)
    }
  }
' "$DICT")

# --- Chequeo 1 (original): columnas version-gated conocidas usadas sin guardia ---

RISKY_COLUMNS=(
  "version_full:18.0"
  "\bcdb\b:12.1"
  "con_id:12.1"
  "instance_role:11.0"
)

check_block() {
  local file="$1" block_content="$2" range_min="$3" range_label="$4"
  block_content=$(echo "$block_content" | sed -E 's/--.*$//')
  for entry in "${RISKY_COLUMNS[@]}"; do
    local col="${entry%%:*}"
    local col_min="${entry##*:}"
    if echo "$block_content" | grep -Eiq "$col"; then
      if ! version_gte "$range_min" "$col_min"; then
        echo "[FAIL] $file — bloque '$range_label' (min declarado $range_min) usa columna gated a $col_min sin guardia"
        FAIL=1
      fi
    fi
  done
}

# --- Chequeo 2 (nuevo, Compatibility Hardening # 7-9): existencia real de columna en la vista ---

# Devuelve, en minúsculas, una columna por línea, las columnas registradas explícitamente para
# $2 (nombre de vista, case-insensitive) dentro de $1 (views.yaml) — SÓLO si esa vista declara
# `columns_exhaustive: true`. Sin ese flag, una vista con `columns:` se trata igual que una vista
# sin `columns:` en absoluto (permisiva) — muchas entradas pre-Fase-5 sólo listan el subconjunto
# de columnas relevante a un bug histórico de version-gating, no un inventario completo (bug real
# encontrado en V$ASM_DISK durante este hardening: ver cabecera de views.yaml).
get_view_columns() {
  local dict="$1" target="$2"
  awk -v target="$target" '
    BEGIN { IGNORECASE=1; inview=0; incols=0; exhaustive=0 }
    /^  [A-Za-z$#0-9_]+:[ \t]*$/ {
      line=$0
      sub(/^  /,"",line); sub(/:[ \t]*$/,"",line)
      inview = (tolower(line) == tolower(target)) ? 1 : 0
      incols=0; exhaustive=0
      next
    }
    inview && /^    columns_exhaustive:[ \t]*true[ \t]*$/ { exhaustive=1; next }
    inview && /^    columns:[ \t]*$/ { incols=1; next }
    inview && incols {
      if (!exhaustive) { next }
      if ($0 ~ /^      [A-Za-z_#][A-Za-z0-9_#]*:/) {
        line=$0
        sub(/^      /,"",line); sub(/:.*/,"",line)
        print tolower(line)
        next
      }
      if ($0 ~ /^[ \t]*#/) { next }
      if ($0 ~ /^[ \t]*$/) { incols=0; next }
      incols=0
    }
  ' "$dict"
}

# Resuelve columnas para una vista, con fallback GV$xxx -> V$xxx (misma convención documentada en
# todo el dictionary: "variante multi-instancia... mismas columnas") + INST_ID siempre permitida
# en cualquier vista GV$ (columna real que Oracle añade en toda vista GV$, no específica de una).
# Cacheada por nombre de vista (declare -A) — evita relanzar awk sobre el mismo dictionary decenas
# de veces por archivo/token; en Windows Git Bash el costo de spawnear procesos es alto y este
# validador recorre todo el catálogo (rendimiento, no sólo corrección).
declare -A __VIEW_COL_CACHE
resolve_columns_for_view() {
  local view_lc="$1"
  if [ -n "${__VIEW_COL_CACHE[$view_lc]+x}" ]; then
    printf '%s' "${__VIEW_COL_CACHE[$view_lc]}"
    return
  fi
  local cols
  cols=$(get_view_columns "$DICT" "$view_lc")
  if [ -z "$cols" ] && [[ "$view_lc" == gv\$* ]]; then
    local vcounterpart="v\$${view_lc#gv\$}"
    cols=$(get_view_columns "$DICT" "$vcounterpart")
    if [ -n "$cols" ]; then
      cols="$cols"$'\n'"inst_id"
    fi
  fi
  __VIEW_COL_CACHE["$view_lc"]="$cols"
  printf '%s' "$cols"
}

# Extrae pares alias:vista desde el segmento FROM..JOIN (ya recortado antes de WHERE/GROUP/ORDER/;).
# Soporta comma-join legacy ("v$instance i, v$database d") y ANSI JOIN ("... JOIN v$x y ON ...").
# La vista sin alias explícito se registra bajo el alias centinela "__bare__".
extract_aliases() {
  local flat="$1"
  local -a words
  read -ra words <<< "$flat"
  local n=${#words[@]}
  local i=0
  while [ $i -lt $n ]; do
    local w="${words[$i]}"
    local wl
    wl=$(echo "$w" | tr 'A-Z' 'a-z' | tr -d ',')
    # Un token es candidato a objeto de vista/dictionary si contiene "$" (V$/GV$, comportamiento
    # histórico) O si coincide exactamente con un objeto registrado en el dictionary (DBA_*, CDB_*,
    # ALL_*, USER_*, ROLE_*, AUDIT_*, UNIFIED_*, REDACTION_*, ... — # 14 del prompt de hardening).
    if [[ "$wl" == *'$'* ]] || [ -n "${ALL_DICT_OBJECTS[$wl]+x}" ]; then
      local alias=""
      local j=$((i+1))
      if [ $j -lt $n ]; then
        local nxt nxtl
        nxt="${words[$j]}"
        nxtl=$(echo "$nxt" | tr 'A-Z' 'a-z' | tr -d ',')
        case "$nxtl" in
          join|on|where|group|order|"") alias="" ;;
          *'$'*) alias="" ;;
          *)
            if [ -n "${ALL_DICT_OBJECTS[$nxtl]+x}" ]; then
              alias=""
            else
              alias="$nxtl"
            fi
            ;;
        esac
      fi
      if [ -n "$alias" ]; then
        echo "${alias}:${wl}"
        i=$((i+2))
      else
        echo "__bare__:${wl}"
        i=$((i+1))
      fi
    else
      i=$((i+1))
    fi
  done
}

# Divide una lista SELECT en items respetando profundidad de paréntesis (para no partir
# MAX(CASE WHEN x THEN y END) por una coma que en este caso no existe, pero sí podría en el futuro).
# Implementado en bash puro (sin subproceso por invocación — antes usaba python3, con un costo de
# arranque de intérprete alto y repetido en Windows Git Bash que hacía el validador impracticablemente
# lento sobre el catálogo completo).
split_select_items() {
  local list="$1"
  local depth=0 cur="" ch item
  local -a out=()
  local len=${#list}
  local i
  for (( i=0; i<len; i++ )); do
    ch="${list:i:1}"
    case "$ch" in
      '(') depth=$((depth+1)); cur+="$ch" ;;
      ')') depth=$((depth-1)); cur+="$ch" ;;
      ',')
        if [ "$depth" -eq 0 ]; then
          out+=("$cur")
          cur=""
        else
          cur+="$ch"
        fi
        ;;
      *) cur+="$ch" ;;
    esac
  done
  out+=("$cur")
  for item in "${out[@]}"; do
    # trim con builtins de bash (sin sed/subproceso)
    item="${item#"${item%%[![:space:]]*}"}"
    item="${item%"${item##*[![:space:]]}"}"
    [ -n "$item" ] && printf '%s\n' "$item"
  done
}

# --- Chequeo 3 (nuevo, PHASE 6 — QUERY COMPATIBILITY & DICTIONARY CERTIFICATION HARDENING,
# # 27 del prompt): view-level y column-level min_version cross-check contra el rango declarado
# del bloque SQL. Causa raíz de que V$RSRCPDBMETRIC (min_version "12.1" incorrecto, real "12.2") y
# PDB_PLUG_IN_VIOLATIONS.CON_ID (min_version "12.1" incorrecto, real "12.2") certificaran SQL
# incorrecto sin que ningún test lo detectara: chequeo 2 sólo validaba EXISTENCIA de columna,
# nunca si esa columna/vista ya existía en el mínimo declarado del bloque. Este chequeo compara
# min_version (de la vista y, para vistas columns_exhaustive:true, de cada columna) contra el
# range_min del bloque, con soporte de patch-level (ej. "12.1.0.2") vía scripts/lib/version.sh
# (PHASE 6 — FINAL PDB IDENTITY & PATCH-LEVEL RESOLVER HARDENING, # 22 del prompt: "el Static
# Validator debe utilizar la misma comparación... no mantener lógica paralela"). El chequeo 1
# (RISKY_COLUMNS) usa la misma librería — ver arriba.

get_view_min_version() {
  local dict="$1" target="$2"
  awk -v target="$target" '
    BEGIN { IGNORECASE=1; inview=0 }
    /^  [A-Za-z$#0-9_]+:[ \t]*$/ {
      line=$0; sub(/^  /,"",line); sub(/:[ \t]*$/,"",line)
      inview = (tolower(line) == tolower(target)) ? 1 : 0
      next
    }
    inview && /^    min_version:/ {
      line=$0
      sub(/^    min_version:[ \t]*/,"",line)
      sub(/[ \t]*#.*$/,"",line)
      gsub(/"/,"",line)
      sub(/[ \t]*$/,"",line)
      print line
      exit
    }
  ' "$dict"
}

get_view_column_min_versions() {
  local dict="$1" target="$2"
  awk -v target="$target" '
    BEGIN { IGNORECASE=1; inview=0; incols=0; exhaustive=0 }
    /^  [A-Za-z$#0-9_]+:[ \t]*$/ {
      line=$0; sub(/^  /,"",line); sub(/:[ \t]*$/,"",line)
      inview = (tolower(line) == tolower(target)) ? 1 : 0
      incols=0; exhaustive=0
      next
    }
    inview && /^    columns_exhaustive:[ \t]*true[ \t]*$/ { exhaustive=1; next }
    inview && /^    columns:[ \t]*$/ { incols=1; next }
    inview && incols {
      if (!exhaustive) { next }
      if ($0 ~ /^      [A-Za-z_#][A-Za-z0-9_#]*:.*min_version:/) {
        line=$0
        sub(/^      /,"",line)
        colname=line
        sub(/:.*/,"",colname)
        # min_version puede ser un string entre comillas ("12.1", "12.1.0.2") o el bareword
        # especial "all" (= disponible desde 10g, ver cabecera del dictionary) — sin comillas.
        mv=line
        sub(/.*min_version:[ \t]*/,"",mv)
        gsub(/"/,"",mv)
        sub(/}.*/,"",mv)
        sub(/[ \t]*$/,"",mv)
        print tolower(colname) ":" mv
        next
      }
      if ($0 ~ /^[ \t]*#/) { next }
      if ($0 ~ /^[ \t]*$/) { incols=0; next }
      incols=0
    }
  ' "$dict"
}

declare -A __VIEW_MINVER_CACHE
resolve_view_min_version() {
  local view_lc="$1"
  if [ -n "${__VIEW_MINVER_CACHE[$view_lc]+x}" ]; then
    printf '%s' "${__VIEW_MINVER_CACHE[$view_lc]}"
    return
  fi
  local mv
  mv=$(get_view_min_version "$DICT" "$view_lc")
  if [ -z "$mv" ] && [[ "$view_lc" == gv\$* ]]; then
    mv=$(get_view_min_version "$DICT" "v\$${view_lc#gv\$}")
  fi
  __VIEW_MINVER_CACHE["$view_lc"]="$mv"
  printf '%s' "$mv"
}

declare -A __VIEW_COLVER_CACHE
resolve_col_min_versions_for_view() {
  local view_lc="$1"
  if [ -n "${__VIEW_COLVER_CACHE[$view_lc]+x}" ]; then
    printf '%s' "${__VIEW_COLVER_CACHE[$view_lc]}"
    return
  fi
  local cv
  cv=$(get_view_column_min_versions "$DICT" "$view_lc")
  if [ -z "$cv" ] && [[ "$view_lc" == gv\$* ]]; then
    cv=$(get_view_column_min_versions "$DICT" "v\$${view_lc#gv\$}")
  fi
  __VIEW_COLVER_CACHE["$view_lc"]="$cv"
  printf '%s' "$cv"
}

check_columns_exist() {
  local file="$1" block="$2" label="$3" range_min="${4:-}"

  # Salida rápida (rendimiento): si el bloque no menciona ninguna de las vistas registradas como
  # columns_exhaustive:true, no hay nada que verificar — evita el costo de extracción/tokenizado
  # completo sobre el resto del catálogo (decenas de queries fuera de Data Guard).
  if ! echo "$block" | grep -qiFf "$EXHAUSTIVE_VIEWS_FILE"; then
    return 0
  fi

  # Abstenerse ante subqueries anidadas en el SELECT — no es un parser SQL completo (# 8).
  if echo "$block" | grep -qi '(SELECT'; then
    return 0
  fi

  local clean flat
  clean=$(echo "$block" | sed -E 's/--.*$//')
  flat=$(echo "$clean" | tr '\n' ' ' | sed -E 's/ +/ /g')

  [ -z "$(echo "$flat" | grep -io 'SELECT' )" ] && return 0
  [ -z "$(echo "$flat" | grep -io 'FROM' )" ] && return 0

  local select_list
  select_list=$(echo "$flat" | grep -ioE 'SELECT .*' | sed -E 's/ FROM .*//I' | sed -E 's/^SELECT //I')

  local from_seg
  from_seg=$(echo "$flat" | grep -ioE 'FROM .*' | sed -E 's/;.*//' | sed -E 's/ WHERE .*//I; s/ GROUP .*//I; s/ ORDER .*//I')
  from_seg=$(echo "$from_seg" | sed -E 's/^FROM //I')

  local alias_map
  alias_map=$(extract_aliases "$from_seg")
  local nviews
  nviews=$(echo "$alias_map" | grep -c ':' || true)

  # Chequeo 3a (view-level): el bloque declara un range_min explícito y alguna vista referenciada
  # tiene min_version registrado en el dictionary por encima de ese range_min.
  if [ -n "$range_min" ]; then
    local seen_views=""
    while IFS= read -r pair; do
      [ -z "$pair" ] && continue
      local vw
      vw=$(echo "$pair" | cut -d: -f2)
      [ -z "$vw" ] && continue
      echo "$seen_views" | grep -qx "$vw" && continue
      seen_views="$seen_views
$vw"
      local view_min
      view_min=$(resolve_view_min_version "$vw")
      [ -z "$view_min" ] && continue
      if ! version_gte "$range_min" "$view_min"; then
        echo "[FAIL] $file — bloque '$label' (min declarado $range_min) referencia '$vw', cuyo min_version real es $view_min (compatibility/oracle-dictionary/views.yaml)"
        FAIL=1
      fi
    done <<< "$alias_map"
  fi

  local items
  items=$(split_select_items "$select_list")

  while IFS= read -r item; do
    [ -z "$item" ] && continue
    local core
    core=$(echo "$item" | sed -E 's/ +AS +[A-Za-z_][A-Za-z0-9_]*$//I')
    core=$(echo "$core" | sed -E "s/'[^']*'//g")

    local tokens
    tokens=$(echo "$core" | grep -oE '[A-Za-z_][A-Za-z0-9_]*\.[A-Za-z_][A-Za-z0-9_#]*|[A-Za-z_][A-Za-z0-9_#]*')

    while IFS= read -r tok; do
      [ -z "$tok" ] && continue
      local col_alias="" col_name="$tok"
      if [[ "$tok" == *.* ]]; then
        col_alias="${tok%%.*}"
        col_name="${tok#*.}"
      fi
      local col_alias_l col_name_l
      col_alias_l=$(echo "$col_alias" | tr 'A-Z' 'a-z')
      col_name_l=$(echo "$col_name" | tr 'A-Z' 'a-z')

      case "$col_name_l" in
        case|when|then|else|end|as|distinct|null|and|or|not|count|max|min|sum|avg|select|from|join|on|where|group|by|order|union|all|in|to_char|to_number|nvl|decode|trunc|round|cast) continue ;;
      esac

      local target_view=""
      if [ -n "$col_alias_l" ]; then
        target_view=$(echo "$alias_map" | grep "^${col_alias_l}:" | head -1 | cut -d: -f2)
      elif [ "$nviews" -eq 1 ]; then
        target_view=$(echo "$alias_map" | grep '^__bare__:' | head -1 | cut -d: -f2)
      fi
      [ -z "$target_view" ] && continue

      local valid_cols
      valid_cols=$(resolve_columns_for_view "$target_view")
      [ -z "$valid_cols" ] && continue

      if ! echo "$valid_cols" | grep -qx "$col_name_l"; then
        echo "[FAIL] $file — bloque '$label' referencia columna '$col_name_l' que no existe en '$target_view' (compatibility/oracle-dictionary/views.yaml)"
        FAIL=1
      elif [ -n "$range_min" ]; then
        # Chequeo 3b (column-level): la columna existe, pero ¿existe ya en el range_min declarado
        # del bloque? (causa raíz real de PDB_PLUG_IN_VIOLATIONS.CON_ID: existía en la vista desde
        # siempre según el chequeo 2, pero no desde el min_version que el bloque declaraba).
        local col_min
        col_min=$(resolve_col_min_versions_for_view "$target_view" | grep "^${col_name_l}:" | head -1 | cut -d: -f2)
        if [ -n "$col_min" ]; then
          if ! version_gte "$range_min" "$col_min"; then
            echo "[FAIL] $file — bloque '$label' (min declarado $range_min) selecciona '$target_view.$col_name_l', cuyo min_version real es $col_min (compatibility/oracle-dictionary/views.yaml)"
            FAIL=1
          fi
        fi
      fi
    done <<< "$tokens"
  done <<< "$items"
}

# --- Chequeo 4 (nuevo, PHASE 7 — RMAN LEGACY SQL SYNTAX & QUERY CERTIFICATION HARDENING, # 17-18
# del prompt): SQL syntax feature version-gating. Dimensión ortogonal a los chequeos 1-3 (vistas/
# columnas) — un bloque puede referenciar sólo vistas/columnas válidas para su min_version y AÚN
# ASÍ ser NOT_CERTIFIED si usa una construcción de sintaxis SQL (ej. la row limiting clause FETCH
# FIRST/OFFSET, ANSI SQL:2008, 12.1+) no disponible en ese min_version — causa raíz real de que 10
# queries queries/rman/Q-RMAN-*.md certificaran FETCH FIRST con min_version 10.2 sin que ningún
# chequeo existente lo detectara (# 5 del prompt de este hardening: "por qué pudo pasar").
SYNTAX_FEATURES="$ROOT/compatibility/oracle-sql-syntax/features.yaml"

get_feature_ids() {
  awk '/^  [A-Za-z_][A-Za-z0-9_]*:[ \t]*$/ { line=$0; sub(/^  /,"",line); sub(/:[ \t]*$/,"",line); print line }' "$SYNTAX_FEATURES"
}

get_feature_block() {
  local target="$1"
  awk -v target="$target" '
    BEGIN{IGNORECASE=1; inf=0; started=0}
    /^  [A-Za-z_][A-Za-z0-9_]*:[ \t]*$/ {
      line=$0; sub(/^  /,"",line); sub(/:[ \t]*$/,"",line)
      if (inf && !(tolower(line)==tolower(target))) exit
      inf=(tolower(line)==tolower(target))?1:0
      if (inf) started=1
      next
    }
    inf { print }
  ' "$SYNTAX_FEATURES"
}

check_syntax_features() {
  local file="$1" block_content="$2" label="$3" range_min="${4:-}"
  [ -z "$range_min" ] && return 0
  local flat
  flat=$(echo "$block_content" | sed -E 's/--.*$//' | tr '\n' ' ')

  local feature_id
  while IFS= read -r feature_id; do
    [ -z "$feature_id" ] && continue
    local fblock
    fblock=$(get_feature_block "$feature_id")
    local feat_min
    feat_min=$(echo "$fblock" | grep -m1 '^    min_version:' | sed -E "s/.*min_version:[ \t]*\"?//; s/\"?[ \t]*\$//")
    [ -z "$feat_min" ] && continue

    local patterns
    patterns=$(echo "$fblock" | grep -E "^      - '" | sed -E "s/^      - '//; s/'[ \t]*\$//")

    while IFS= read -r pat; do
      [ -z "$pat" ] && continue
      if echo "$flat" | grep -qiE "$pat"; then
        if ! version_gte "$range_min" "$feat_min"; then
          echo "[FAIL] $file — bloque '$label' (min declarado $range_min) usa sintaxis '$feature_id', que requiere min_version $feat_min (compatibility/oracle-sql-syntax/features.yaml)"
          FAIL=1
        fi
      fi
    done <<< "$patterns"
  done <<< "$(get_feature_ids)"
}

# --- Queries CON variantes explícitas: validar cada bloque contra el min de SU variante ---
# Patrón de extracción patch-level-aware ([0-9]+(\.[0-9]+){1,3}, no sólo major.minor) — PHASE 6 —
# QUERY COMPATIBILITY & DICTIONARY CERTIFICATION HARDENING, # 6/# 28: Q-CDB-PDB-SAVED-STATE-001
# declara min: "12.1.0.2" (patch-level), el patrón 2-tier anterior no la capturaba en absoluto.
for f in $(grep -rl '^variants:' "$ROOT/queries" --include='Q-*.md' 2>/dev/null); do
  mins=$(grep -oE 'oracle_versions: \{min: "[0-9]+(\.[0-9]+){1,3}"' "$f" | grep -oE '"[0-9]+(\.[0-9]+){1,3}"' | tr -d '"')
  i=0
  while IFS= read -r min; do
    i=$((i+1))
    block=$(awk -v n="$i" '/```sql/{c++} c==n && /```sql/{flag=1;next} flag && /```/{flag=0} flag' "$f")
    check_block "$f" "$block" "$min" "variant #$i"
    check_columns_exist "$f" "$block" "variant #$i" "$min"
    check_syntax_features "$f" "$block" "variant #$i" "$min"
  done <<< "$mins"
done

# --- Queries SIN variantes (implicit_full_range): validar cada bloque SQL del archivo por separado ---
QCM="$ROOT/config/query-compatibility-matrix.yaml"
for f in $(grep -rL '^variants:' "$ROOT/queries" --include='Q-*.md' 2>/dev/null); do
  raw=$(grep -oE '^supported_oracle_versions: \[[^]]*\]' "$f" | head -1)
  first=$(echo "$raw" | sed -E 's/.*\[([^],]*).*/\1/' | tr -d ' ')
  case "$first" in
    10g) min="10.2" ;;
    11g|11gR2) min="11.0" ;;
    12c) min="12.1" ;;
    18c) min="18.0" ;;
    19c) min="19.0" ;;
    21c) min="21.0" ;;
    23ai) min="23.0" ;;
    *) min="10.2" ;;
  esac

  # Chequeo 3 usa un min MÁS PRECISO que el derivado arriba (chequeo 1, sin cambios — la etiqueta
  # "12c" descriptiva de supported_oracle_versions no distingue 12.1/12.2, ver Q-CDB-LOCKDOWN-001/
  # Q-CDB-RESOURCE-USAGE-001, ambas 12.2+-only pero con "12c" en la lista por convención — # 39 del
  # prompt de hardening: "no marcar soporte superior al realmente certificado"). Fuente real:
  # config/query-compatibility-matrix.yaml (min declarado por logical query, implicit_full_range).
  qid=$(grep -m1 '^query_id:' "$f" | awk '{print $2}')
  precise_min="$min"
  if [ -n "$qid" ]; then
    qm=$(grep -m1 "^  ${qid}:" "$QCM" | grep -oE 'min: "[0-9]+(\.[0-9]+){1,3}"' | head -1 | grep -oE '"[0-9]+(\.[0-9]+){1,3}"' | tr -d '"')
    [ -n "$qm" ] && precise_min="$qm"
  fi

  nblocks=$(grep -c '```sql' "$f" || true)
  i=0
  while [ "$i" -lt "$nblocks" ]; do
    i=$((i+1))
    block=$(awk -v n="$i" '/```sql/{c++} c==n && /```sql/{flag=1;next} flag && /```/{flag=0} flag' "$f")
    check_block "$f" "$block" "$min" "implicit_full_range #$i"
    check_columns_exist "$f" "$block" "implicit_full_range #$i" "$precise_min"
    check_syntax_features "$f" "$block" "implicit_full_range #$i" "$precise_min"
  done
done

[ $FAIL -eq 0 ] && echo "[PASS] SQL Static Validator: ningún bloque SQL certificado referencia una columna fuera de su rango de versión declarado, una columna inexistente en la vista referenciada, ni una sintaxis SQL (FETCH FIRST/OFFSET) por debajo de su min_version real"

exit $FAIL
