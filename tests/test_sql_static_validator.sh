#!/usr/bin/env bash
# SQL Static Validator (sección 23 del prompt de Compatibility Hardening).
# No es un parser SQL completo: usa metadata estructurada (compatibility/oracle-dictionary/views.yaml)
# + reglas sobre un conjunto conocido de columnas version-gated, y valida que ningún bloque SQL
# certificado (variante o rango implícito) las use fuera de la versión donde existen.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

# Columnas version-gated conocidas, extraídas de compatibility/oracle-dictionary/views.yaml.
# Formato: "columna:min_major.min_minor"
RISKY_COLUMNS=(
  "version_full:18.0"
  "\bcdb\b:12.1"
  "con_id:12.1"
  "instance_role:11.0"
)

vernum() { # "12.1" -> 1201 ; "18.0" -> 1800 ; "10.2" -> 1002
  local v="$1"
  local maj min
  maj=$(echo "$v" | cut -d. -f1)
  min=$(echo "$v" | cut -d. -f2)
  printf "%d" $((maj * 100 + min))
}

check_block() {
  local file="$1" block_content="$2" range_min="$3" range_label="$4"
  local range_min_num
  range_min_num=$(vernum "$range_min")
  # Quitar comentarios de linea SQL (-- ...) antes de evaluar: un comentario que MENCIONA una
  # columna riesgosa para explicar por que NO se usa no debe contar como uso real.
  block_content=$(echo "$block_content" | sed -E 's/--.*$//')
  for entry in "${RISKY_COLUMNS[@]}"; do
    local col="${entry%%:*}"
    local col_min="${entry##*:}"
    local col_min_num
    col_min_num=$(vernum "$col_min")
    if echo "$block_content" | grep -Eiq "$col"; then
      if [ "$range_min_num" -lt "$col_min_num" ]; then
        echo "[FAIL] $file — bloque '$range_label' (min declarado $range_min) usa columna gated a $col_min sin guardia"
        FAIL=1
      fi
    fi
  done
}

# --- Queries CON variantes explícitas: validar cada bloque contra el min de SU variante ---
for f in $(grep -rl '^variants:' "$ROOT/queries" --include='Q-*.md' 2>/dev/null); do
  # Extraer pares (label, min) desde las líneas "oracle_versions: {min: "X.Y", ...}" en orden de aparición,
  # y los headings "# ... — Variant ... (label, ...)" con su bloque sql inmediatamente siguiente.
  mins=$(grep -oE 'oracle_versions: \{min: "[0-9]+\.[0-9]+"' "$f" | grep -oE '"[0-9]+\.[0-9]+"' | tr -d '"')
  i=0
  while IFS= read -r min; do
    i=$((i+1))
    # bloque sql i-esimo del archivo
    block=$(awk -v n="$i" '/```sql/{c++} c==n && /```sql/{flag=1;next} flag && /```/{flag=0} flag' "$f")
    check_block "$f" "$block" "$min" "variant #$i"
  done <<< "$mins"
done

# --- Queries SIN variantes (implicit_full_range): validar el único bloque contra el min declarado ---
for f in $(grep -rL '^variants:' "$ROOT/queries" --include='Q-*.md' 2>/dev/null); do
  raw=$(grep -oE '^supported_oracle_versions: \[[^]]*\]' "$f" | head -1)
  # Tomar el primer token de la lista y mapear a version numerica minima conservadora
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
  block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$f")
  check_block "$f" "$block" "$min" "implicit_full_range"
done

[ $FAIL -eq 0 ] && echo "[PASS] SQL Static Validator: ningún bloque SQL certificado referencia una columna fuera de su rango de versión declarado"

exit $FAIL
