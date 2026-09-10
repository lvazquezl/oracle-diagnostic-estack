#!/usr/bin/env bash
# PHASE 6 — VERSION RESOLVER CONSOLIDATION FINALIZATION (# 8-9 del prompt): endurecido de un
# allowlist de 7 archivos (Final PDB Identity & Patch-Level Resolver Hardening) a una verificación
# global real:
#   1) Delega la comprobación negativa (ningún vernum()/vernum3() local en ningún archivo
#      ejecutable) a tests/test_no_local_version_resolvers_in_tests.sh — fuente única de esa
#      lógica, no duplicada aquí (mismo patrón "alias/wrapper" que
#      tests/test_no_variant_references_unknown_column.sh delega a
#      tests/test_sql_static_validator.sh).
#   2) Comprobación positiva: todo test que invoque una función de la librería compartida
#      (version_gte/version_lte/version_in_range/compare_oracle_versions/normalize_oracle_version)
#      debe sourcearla — nunca se exige el import a un test que no compara versiones (# 9 del
#      prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

# --- 1) Ningún comparador local en ningún archivo ejecutable (chequeo global delegado) ---
if ! bash "$ROOT/tests/test_no_local_version_resolvers_in_tests.sh"; then
  echo "[FAIL] tests/test_no_local_version_resolvers_in_tests.sh encontró comparadores de versión locales — ver su salida arriba"
  FAIL=1
fi

# --- 2) Todo test que usa una función de la librería debe sourcearla ---
LIB_FUNCS='version_gte|version_lte|version_in_range|compare_oracle_versions|normalize_oracle_version'
SELF="$ROOT/tests/test_query_variant_resolver_uses_shared_version_library.sh"
n_checked=0
while IFS= read -r f; do
  [ -f "$f" ] || continue
  # Excluir scripts/lib/version.sh (declara las funciones, no las "usa" importándolas) y este
  # propio archivo (su mensaje de error cita los nombres de función textualmente, falso positivo
  # auto-referencial).
  [ "$f" = "$ROOT/scripts/lib/version.sh" ] && continue
  [ "$f" = "$SELF" ] && continue

  if grep -qE "\b($LIB_FUNCS)\b" "$f"; then
    n_checked=$((n_checked+1))
    # Acepta tanto `source scripts/lib/version.sh` literal como sourcing indirecto vía variable
    # (ej. LIB=".../scripts/lib/version.sh"; source "$LIB") — basta con que el archivo referencie
    # la ruta y contenga una sentencia `source`.
    if grep -q 'scripts/lib/version\.sh' "$f" && grep -qE '(^|[^A-Za-z_])source[[:space:]]' "$f"; then
      echo "[PASS] $(basename "$f") usa la librería compartida y la sourcea"
    else
      echo "[FAIL] $(basename "$f") invoca ($LIB_FUNCS) pero no sourcea scripts/lib/version.sh"
      FAIL=1
    fi
  fi
done < <(find "$ROOT/tests" -maxdepth 1 -name '*.sh' -type f)

[ "$n_checked" -gt 0 ] && echo "[PASS] $n_checked tests que invocan la librería compartida la sourcean correctamente" || { echo "[FAIL] no se encontró ningún test invocando la librería compartida — inesperado tras la migración"; FAIL=1; }

exit $FAIL
