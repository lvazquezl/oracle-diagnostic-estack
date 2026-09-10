#!/usr/bin/env bash
# PHASE 6 — QUERY COMPATIBILITY & DICTIONARY CERTIFICATION HARDENING, # 27.
# Valida que el SQL Static Validator es version-aware a nivel view+column+version+variant — no
# sólo existencia (chequeo 2 pre-hardening). Ejemplo nombrado en el prompt:
# PDB_PLUG_IN_VIOLATIONS.CON_ID debe ser INVALID en legacy (12.1), VALID en modern (12.2+), y el
# validator debe distinguirlo.
#
# PHASE 6 — FINAL PDB IDENTITY & PATCH-LEVEL RESOLVER HARDENING (# 21-22, # 24 del prompt):
# vernum3() dejó de existir como función local — la comparación de versión ahora vive en
# scripts/lib/version.sh (compartida, patch-level-aware), consumida vía version_gte. Este chequeo
# se actualiza para reflejar esa arquitectura en vez de exigir un helper local ya eliminado
# deliberadamente (ver tests/test_static_validator_uses_shared_version_library.sh para el chequeo
# dedicado de esa integración).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
VALIDATOR="$ROOT/tests/test_sql_static_validator.sh"
DICT="$ROOT/compatibility/oracle-dictionary/views.yaml"

grep -q 'source .*scripts/lib/version\.sh' "$VALIDATOR" && echo "[PASS] test_sql_static_validator.sh sourcea scripts/lib/version.sh (chequeo 3, version-aware, patch-level-capable)" || { echo "[FAIL] test_sql_static_validator.sh no sourcea scripts/lib/version.sh"; FAIL=1; }

for fn in get_view_min_version get_view_column_min_versions resolve_view_min_version resolve_col_min_versions_for_view; do
  grep -q "^${fn}()" "$VALIDATOR" && echo "[PASS] test_sql_static_validator.sh declara $fn (chequeo 3, version-aware)" || { echo "[FAIL] falta $fn en test_sql_static_validator.sh"; FAIL=1; }
done

grep -q 'check_columns_exist() {' "$VALIDATOR" && grep -A1 'check_columns_exist() {' "$VALIDATOR" | grep -q 'range_min' && echo "[PASS] check_columns_exist recibe range_min (chequeo view/column-level)" || { echo "[FAIL] check_columns_exist no recibe range_min"; FAIL=1; }

# Ejemplo concreto: CON_ID de PDB_PLUG_IN_VIOLATIONS es INVALID en 12.1 (min real 12.2), VALID en 12.2+.
con_id_min=$(awk '
  BEGIN{IGNORECASE=1; inview=0; incols=0}
  /^  [A-Za-z$#0-9_]+:[ \t]*$/{line=$0; sub(/^  /,"",line); sub(/:[ \t]*$/,"",line); inview=(tolower(line)=="pdb_plug_in_violations")?1:0; incols=0; next}
  inview && /^    columns:[ \t]*$/{incols=1; next}
  inview && incols && /con_id:/{line=$0; sub(/.*min_version:[ \t]*"/,"",line); sub(/".*/,"",line); print line; exit}
' "$DICT")

[ "$con_id_min" = "12.2" ] && echo "[PASS] PDB_PLUG_IN_VIOLATIONS.CON_ID modelado como VALID sólo desde 12.2 — INVALID en 12.1 por construcción" || { echo "[FAIL] con_id.min_version = '$con_id_min', esperado 12.2"; FAIL=1; }

exit $FAIL
