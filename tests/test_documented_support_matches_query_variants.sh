#!/usr/bin/env bash
# Valida que la version soportada declarada en cada skill (manifest.yaml) sea alcanzable por
# la union de variantes de su required_evidence -- documentacion vs realidad ejecutable
# (seccion 27 del prompt de Compatibility Hardening).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

check_skill_query() {
  local skill_manifest="$1" query_id="$2" query_file="$3"
  local skill_min
  skill_min=$(grep -oE '^supported_oracle_versions: \[[^]]*\]' "$skill_manifest" | grep -oE '\[[^],]*' | tr -d '[' | tr -d ' ')

  if [ ! -f "$query_file" ]; then
    echo "[FAIL] $skill_manifest requiere $query_id pero el archivo de query no existe: $query_file"
    FAIL=1
    return
  fi

  if grep -q '^variants:' "$query_file"; then
    # union: el minimo de todas las variantes
    lowest=$(grep -oE 'min: "[0-9]+\.[0-9]+"' "$query_file" | grep -oE '[0-9]+\.[0-9]+' | sort -t. -k1,1n -k2,2n | head -1)
    lowest_major=$(echo "$lowest" | cut -d. -f1)
  else
    lowest_major=""
  fi

  case "$skill_min" in
    10g) skill_min_major=10 ;;
    11g) skill_min_major=11 ;;
    12c) skill_min_major=12 ;;
    18c) skill_min_major=18 ;;
    19c) skill_min_major=19 ;;
    *) skill_min_major=10 ;;
  esac

  if [ -n "$lowest_major" ] && [ "$lowest_major" -gt "$skill_min_major" ]; then
    echo "[FAIL] $skill_manifest declara soporte desde '$skill_min' pero $query_id (variantes) sólo cubre desde major $lowest_major"
    FAIL=1
  else
    echo "[PASS] $skill_manifest — soporte declarado ('$skill_min') consistente con la cobertura real de $query_id"
  fi
}

check_skill_query "$ROOT/skills/oracle/instance/manifest.yaml" "Q-ORA-INSTANCE-STATE-001" "$ROOT/queries/oracle/instance/Q-ORA-INSTANCE-STATE-001.md"
check_skill_query "$ROOT/skills/oracle/tablespaces/manifest.yaml" "Q-DBA-TBS-USAGE-001" "$ROOT/queries/oracle/tablespaces/Q-DBA-TBS-USAGE-001.md"

exit $FAIL
