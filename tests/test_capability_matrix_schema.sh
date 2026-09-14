#!/usr/bin/env bash
# Valida el schema minimo de config/capability-matrix.yaml: 18 dominios, cada uno con las 8
# columnas de version y un status dentro del enum permitido.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
F="$ROOT/config/capability-matrix.yaml"
FAIL=0

domain_count=$(grep -c '^  - id:' "$F")
if [ "$domain_count" -eq 18 ]; then
  echo "[PASS] config/capability-matrix.yaml declara 18 dominios"
else
  echo "[FAIL] config/capability-matrix.yaml declara $domain_count dominios, se esperaban 18"
  FAIL=1
fi

for v in 10g 11g 12c 18c 19c 21c 23ai latest; do
  if grep -q "$v:" "$F"; then
    echo "[PASS] columna de versión '$v' presente"
  else
    echo "[FAIL] falta columna de versión '$v'"
    FAIL=1
  fi
done

VALID='PLANNED|FOUNDATION_ONLY|PARTIAL|SUPPORTED|UNSUPPORTED|LICENSE_DEPENDENT'
bad=$(grep -oE '(10g|11g|12c|18c|19c|21c|23ai|latest): [A-Z_]+' "$F" | grep -Ev ": ($VALID)$" || true)
if [ -n "$bad" ]; then
  echo "[FAIL] valores de status fuera del enum permitido:"
  echo "$bad"
  FAIL=1
else
  echo "[PASS] Todos los valores de status están dentro del enum permitido"
fi

exit $FAIL
