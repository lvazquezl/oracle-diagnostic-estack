#!/usr/bin/env bash
# PHASE 6 — VERSION RESOLVER CONSOLIDATION FINALIZATION, # 25-27, # 35-36.
# Enforcement global: recorre todo tests/**/*.sh (código ejecutable, nunca Markdown/comentarios/
# fixtures) buscando definiciones LOCALES de comparadores de versión — vernum()/vernum3()/
# version_to_number()/compare_version() o equivalente. Reporta archivo:línea y falla si encuentra
# alguna. scripts/lib/version.sh queda explícitamente excluido — es precisamente la única
# implementación autorizada (# 27 del prompt), no una reintroducción del anti-patrón.
#
# Ancla el patrón al INICIO de línea (tras espacio en blanco opcional) para evitar falsos
# positivos: una línea de comentario ("# vernum() hacía...") nunca puede matchear porque empieza
# con '#', no con espacio+nombre-de-función (# 10 del prompt: evitar falsos positivos por
# documentación/comentarios/strings de fixture).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

PATTERN='^[[:space:]]*(function[[:space:]]+)?(vernum3?|version_to_number|compare_version)[[:space:]]*\(\)'

while IFS= read -r f; do
  [ -f "$f" ] || continue
  while IFS=: read -r lineno content; do
    [ -z "$lineno" ] && continue
    echo "[FAIL] $f:$lineno declara un comparador de versión local: ${content# }"
    FAIL=1
  done < <(grep -nE "$PATTERN" "$f")
done < <(find "$ROOT/tests" -maxdepth 1 -name '*.sh' -type f)

# scripts/**/*.sh también se revisa (por si un helper local apareciera fuera de tests/) — excepto
# la propia librería canónica.
while IFS= read -r f; do
  [ -f "$f" ] || continue
  [ "$f" = "$ROOT/scripts/lib/version.sh" ] && continue
  while IFS=: read -r lineno content; do
    [ -z "$lineno" ] && continue
    echo "[FAIL] $f:$lineno declara un comparador de versión local: ${content# }"
    FAIL=1
  done < <(grep -nE "$PATTERN" "$f")
done < <(find "$ROOT/scripts" -name '*.sh' -type f 2>/dev/null)

[ $FAIL -eq 0 ] && echo "[PASS] 0 definiciones locales de vernum/vernum3/version_to_number/compare_version en tests/**/*.sh ni scripts/**/*.sh (excepto scripts/lib/version.sh, la implementación canónica)"

exit $FAIL
