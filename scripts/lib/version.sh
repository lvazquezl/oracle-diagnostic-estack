#!/usr/bin/env bash
# scripts/lib/version.sh — Shared Oracle version comparison library.
#
# PHASE 6 — FINAL PDB IDENTITY & PATCH-LEVEL RESOLVER HARDENING (# 16-22 del prompt): única fuente
# de verdad para normalizar y comparar versiones Oracle, reemplazando los helpers vernum()/vernum3()
# duplicados ad-hoc en tests/test_sql_static_validator.sh y tests/test_query_variant_resolver_*.sh
# (2-tier, major.minor únicamente — no podían expresar el boundary patch-level real de
# Q-CDB-PDB-SAVED-STATE-001, 12.1.0.2). Usada por: tests/test_sql_static_validator.sh,
# tests/test_query_variant_resolver_10g.sh/_11g.sh, tests/test_pdb_saved_state_1210*.sh,
# tests/test_saved_state_resolver_*.sh, tests/test_version_compare_*.sh.
#
# No introduce un runtime ejecutable nuevo (el Gateway MCP real sigue siendo Fase 7) — es la misma
# lógica de comparación documentada en docs/QUERY_VARIANTS.md, ahora en un único archivo fuente en
# vez de reimplementada por cada test.
#
# Uso: `source "$ROOT/scripts/lib/version.sh"` y luego llamar a las funciones de abajo.

# normalize_oracle_version <version-string-or-alias>
#   Imprime 5 enteros separados por espacio: "major minor update patch revision".
#   Acepta: aliases de marketing (10g/11g/11gR2/12c/18c/19c/21c/23ai), el sentinel "latest"
#   (tratado como techo sin límite conocido — mismo criterio que vernum("latest")=99999 en las
#   ~40 queries Oracle Core/RAC/ASM/Performance que ya lo usan, docs/QUERY_VARIANTS.md#future-proof-
#   version-policy), el bareword "all" del dictionary (= disponible desde 10g, tratado como el
#   mínimo absoluto), y strings numéricos de 1 a 5 componentes ("12.1", "12.1.0.2", "12.1.0.2.0",
#   "19.27.0.0.0"). Componentes faltantes se rellenan con 0 de forma determinista (# 17 del prompt).
normalize_oracle_version() {
  local v="$1"

  case "$v" in
    latest)
      printf '%s %s %s %s %s' 999999 999999 999999 999999 999999
      return
      ;;
    all)
      # "all" = disponible desde 10g (mínimo soportado por el catálogo, ver cabecera de
      # compatibility/oracle-dictionary/views.yaml) — nunca un boundary real por sí solo, así que
      # se normaliza al mínimo absoluto (0.0.0.0.0), consistente con "cualquier min real es >= all".
      printf '%s %s %s %s %s' 0 0 0 0 0
      return
      ;;
  esac

  # Marketing version mapping — mismos alias ya usados en config/query-compatibility-matrix.yaml
  # y en el case histórico de tests/test_sql_static_validator.sh (# 19 del prompt: "mantener
  # mappings ya existentes", no inventar soporte para major futura desconocida).
  case "$v" in
    10g) v="10.2" ;;
    11g|11gR2) v="11.0" ;;
    12c) v="12.1" ;;
    18c) v="18.0" ;;
    19c) v="19.0" ;;
    21c) v="21.0" ;;
    23ai) v="23.0" ;;
  esac

  local IFS=.
  local -a parts
  read -ra parts <<< "$v"
  local maj="${parts[0]:-0}" min="${parts[1]:-0}" upd="${parts[2]:-0}" pat="${parts[3]:-0}" rev="${parts[4]:-0}"

  # Defensivo: descarta cualquier caracter no numérico residual (ej. sufijos) en vez de fallar —
  # nunca deja un componente vacío, que rompería la aritmética entera downstream.
  maj=${maj//[!0-9]/}; min=${min//[!0-9]/}; upd=${upd//[!0-9]/}; pat=${pat//[!0-9]/}; rev=${rev//[!0-9]/}
  [ -z "$maj" ] && maj=0
  [ -z "$min" ] && min=0
  [ -z "$upd" ] && upd=0
  [ -z "$pat" ] && pat=0
  [ -z "$rev" ] && rev=0

  printf '%s %s %s %s %s' "$maj" "$min" "$upd" "$pat" "$rev"
}

# compare_oracle_versions <a> <b>
#   Imprime -1 si a<b, 0 si a==b, 1 si a>b — comparación tupla-por-tupla (# 17, # 20 del prompt),
#   correcta para minors de más de un dígito (19.3 < 19.27, nunca comparación de string).
compare_oracle_versions() {
  local a="$1" b="$2"
  local -a ta tb
  read -ra ta <<< "$(normalize_oracle_version "$a")"
  read -ra tb <<< "$(normalize_oracle_version "$b")"
  local i
  for i in 0 1 2 3 4; do
    if [ "${ta[$i]}" -lt "${tb[$i]}" ]; then echo "-1"; return; fi
    if [ "${ta[$i]}" -gt "${tb[$i]}" ]; then echo "1"; return; fi
  done
  echo "0"
}

# version_gte <a> <b>  -> exit 0 si a>=b, exit 1 si no.
version_gte() { [ "$(compare_oracle_versions "$1" "$2")" != "-1" ]; }

# version_lte <a> <b>  -> exit 0 si a<=b, exit 1 si no.
version_lte() { [ "$(compare_oracle_versions "$1" "$2")" != "1" ]; }

# version_in_range <v> <min> <max>  -> exit 0 si min<=v<=max, exit 1 si no.
version_in_range() {
  local v="$1" min="$2" max="$3"
  version_gte "$v" "$min" && version_lte "$v" "$max"
}
