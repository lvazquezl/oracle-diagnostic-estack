#!/usr/bin/env bash
# Valida que, para cada fixture (tests/fixtures/*.yaml), el Query Variant Resolver seleccione
# una variante cuyas columnas version-gated sean consistentes con compatibility_schema.available_columns
# de esa fixture (seccion 26 del prompt de Compatibility Hardening: "Los tests deberan validar la
# query seleccionada contra ese fixture").
#
# PHASE 6 — VERSION RESOLVER CONSOLIDATION FINALIZATION (# 6, # 17 del prompt): usa
# scripts/lib/version.sh en vez de un vernum() local.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/version.sh"
FAIL=0

RISKY_COLUMNS=("version_full:V\$INSTANCE.version_full" "\bcdb\b:V\$DATABASE.cdb" "con_id:V\$ACTIVE_INSTANCES.con_id" "instance_role:V\$INSTANCE.instance_role")

for fx in "$ROOT"/tests/fixtures/*.yaml; do
  fx_name=$(basename "$fx")

  # Fixtures del dominio OS (Fase 9, os/*) no versionan por Oracle version -- oracle_version/
  # compatibility_schema no aplican, el Query Variant Resolver no interviene en su dominio (evidencia
  # de collectors semanticos, no queries SQL). Se marcan por el top-level os_target: en vez de
  # oracle_version:, y quedan fuera de alcance de este test, no un fallo.
  if grep -q '^os_target:' "$fx" && ! grep -q 'oracle_version:' "$fx"; then
    continue
  fi

  grep -q '^compatibility_schema:' "$fx" || { echo "[FAIL] $fx_name — sin compatibility_schema (seccion 26)"; FAIL=1; continue; }

  major=$(grep -m1 'oracle_version:' "$fx" | grep -oE 'major: [0-9]+' | grep -oE '[0-9]+')
  minor=$(grep -m1 'oracle_version:' "$fx" | grep -oE 'minor: [0-9]+' | grep -oE '[0-9]+')
  target="${major}.${minor}"

  for f in $(grep -rl '^variants:' "$ROOT/queries" --include='Q-*.md' 2>/dev/null); do
    qid=$(grep -m1 '^query_id:' "$f" | awk '{print $2}')
    ranges=$(grep -oE 'oracle_versions: \{min: "[^"]+", max: [^}]+\}' "$f")
    i=0
    resolved_i=0
    while IFS= read -r r; do
      i=$((i+1))
      m=$(echo "$r" | grep -oE 'min: "[^"]+"' | grep -oE '"[^"]+"' | tr -d '"')
      x=$(echo "$r" | grep -oE 'max: [^}]+' | sed -E 's/max: *"?//; s/"?$//')
      if version_in_range "$target" "$m" "$x" && [ "$resolved_i" -eq 0 ]; then
        resolved_i=$i
      fi
    done <<< "$ranges"

    [ "$resolved_i" -eq 0 ] && continue   # sin variante para esta version -> fuera de alcance de este test (cubierto por test_query_variant_resolver_*)

    block=$(awk -v n="$resolved_i" '/```sql/{c++} c==n && /```sql/{flag=1;next} flag && /```/{flag=0} flag' "$f" | sed -E 's/--.*$//')

    for entry in "${RISKY_COLUMNS[@]}"; do
      col="${entry%%:*}"
      colkey="${entry##*:}"
      if echo "$block" | grep -Eiq "$col"; then
        avail=$(grep -F "\"$colkey\":" "$fx" | grep -oE 'true|false')
        if [ "$avail" = "false" ]; then
          echo "[FAIL] $fx_name / $qid — variante resuelta (#$resolved_i) usa columna '$colkey' pero la fixture la declara no disponible"
          FAIL=1
        fi
      fi
    done
  done
done

[ $FAIL -eq 0 ] && echo "[PASS] Para cada fixture, la variante resuelta por el Query Variant Resolver es consistente con su compatibility_schema.available_columns"

exit $FAIL
