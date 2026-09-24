#!/usr/bin/env bash
# Cada collector declara un command_family fijo (allowlisted), sin concatenación de parámetros
# arbitrarios — verifica que el catálogo documenta comandos completos, no plantillas con
# interpolación libre (ausencia de patrones tipo $CMD, ${var}, %s sin acotar en la tabla).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
DOC="$ROOT/docs/GI_READONLY_COLLECTORS.md"

if grep -E '\| get_[a-z_]+ \|' "$DOC" | grep -qE '\$\{|\$\(|%s'; then
  echo "[FAIL] el catálogo de collectors contiene interpolación de comando no acotada"
  FAIL=1
else
  echo "[PASS] ningún collector documenta interpolación de comando arbitraria"
fi

# Cada comando en la tabla debe ser uno de los binarios allowlisted del dominio GI/ASM/Net.
# CHG-ESTACK-PORTABILITY-001: 'ss' también cuando va entre comillas invertidas (`ss`/…), y lectura de ruta FIJA
# /etc/hostname (get_host_identity). Estas dos filas nunca se habían revisado en GNU (ver el patrón [`] abajo);
# el "o equivalente" del documento queda para HUMAN REVIEW (CHG-REQ-DOC-GI-HOSTNAME).
ALLOWED='olsnodes|crsctl|srvctl|lsnrctl|oifcfg|ocrcheck|asmcmd|ip |ss |[`]ss[`]|getent|nslookup|lectura de [`]/etc/hostname[`]'
# CHG-ESTACK-PORTABILITY-001: [`] literal; con \` GNU grep lo interpretaba como ancla de inicio de buffer y el
# patrón no coincidía con ninguna fila (el test pasaba sin revisar nada en Windows/Linux).
if grep -E '^\| [`]get_' "$DOC" | grep -vE "$ALLOWED"; then
  echo "[FAIL] fila de collector con comando fuera del allowlist detectada arriba"
  FAIL=1
else
  echo "[PASS] todos los collectors mapean a un binario allowlisted"
fi

exit $FAIL
